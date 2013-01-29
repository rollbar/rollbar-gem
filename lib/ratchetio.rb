require 'net/https'
require 'securerandom' if defined?(SecureRandom)
require 'socket'
require 'thread'
require 'uri'

require "girl_friday" if defined?(GirlFriday)

require 'ratchetio/version'
require 'ratchetio/configuration'
require 'ratchetio/request_data_extractor'
require 'ratchetio/exception_reporter'

require 'ratchetio/delayed_job' if defined?(Delayed) && defined?(Delayed::Plugins)
require 'ratchetio/sidekiq' if defined?(Sidekiq)
require 'ratchetio/goalie' if defined?(Goalie)
require 'ratchetio/rack' if defined?(Rack)
require 'ratchetio/railtie' if defined?(Rails)

module Ratchetio
  class << self
    attr_writer :configuration
    attr_reader :last_report

    # Configures the gem.
    #
    # Call on app startup to set the `access_token` (required) and other config params.
    # In a Rails app, this is called by `config/initializers/ratchetio.rb` which is generated
    # with `rails generate ratchetio access-token-here`
    #
    # @example
    #   Ratchetio.configure do |config|
    #     config.access_token = 'abcdefg'
    #   end
    def configure
      yield(configuration)
    end

    def reconfigure
      @configuration = Configuration.new
      yield(configuration)
    end

    # Returns the configuration object.
    #
    # @return [Ratchetio::Configuration] The configuration object
    def configuration
      @configuration ||= Configuration.new
    end

    # Reports an exception to Ratchet.io. Returns the exception data hash.
    #
    # @example
    #   begin
    #     foo = bar
    #   rescue => e
    #     Ratchetio.report_exception(e)
    #   end
    #
    # @param exception [Exception] The exception object to report
    # @param request_data [Hash] Data describing the request. Should be the result of calling
    #   `ratchetio_request_data`.
    # @param person_data [Hash] Data describing the affected person. Should be the result of calling
    #   `ratchetio_person_data`
    def report_exception(exception, request_data = nil, person_data = nil)
      return 'disabled' unless configuration.enabled
      return 'ignored' if ignored?(exception)

      data = exception_data(exception, filtered_level(exception))
      data[:request] = request_data if request_data
      data[:person] = person_data if person_data

      @last_report = data

      payload = build_payload(data)
      schedule_payload(payload)
      data
    rescue => e
      logger.error "[Ratchet.io] Error reporting exception to Ratchet.io: #{e}"
      'error'
    end

    # Reports an arbitrary message to Ratchet.io
    #
    # @example
    #   Ratchetio.report_message("User login failed", 'info', :user_id => 123)
    #
    # @param message [String] The message body. This will be used to identify the message within
    #   Ratchet. For best results, avoid putting variables in the message body; pass them as
    #   `extra_data` instead.
    # @param level [String] The level. One of: 'critical', 'error', 'warning', 'info', 'debug'
    # @param extra_data [Hash] Additional data to include alongside the body. Don't use 'body' as
    #   it is reserved.
    def report_message(message, level = 'info', extra_data = {})
      unless configuration.enabled
        return
      end

      data = message_data(message, level, extra_data)
      payload = build_payload(data)
      schedule_payload(payload)
    rescue => e
      logger.error "[Ratchet.io] Error reporting message to Ratchet.io: #{e}"
    end

    # Turns off reporting for the given block.
    #
    # @example
    #   Ratchetio.silenced { raise }
    #
    # @yield Block which exceptions won't be reported.
    def silenced
      begin
        yield
      rescue => e
        e.instance_variable_set(:@_ratchet_do_not_report, true)
        raise
      end
    end

    def process_payload(payload)
      begin
        if configuration.write_to_file
          write_payload(payload)
        else
          send_payload(payload)
        end
      rescue => e
        logger.error "[Ratchet.io] Error reporting message to Ratchet.io: #{e}"
      end
    end

    private

    def ignored?(exception)
      if filtered_level(exception) == 'ignore'
        return true
      end

      if exception.instance_variable_get(:@_ratchet_do_not_report)
        return true
      end

      false
    end

    def filtered_level(exception)
      configuration.exception_level_filters[exception.class.name]
    end

    def message_data(message, level, extra_data)
      data = base_data(level)

      data[:body] = {
        :message => {
          :body => message.to_s
        }
      }
      data[:body][:message].merge!(extra_data)
      data[:server] = server_data

      data
    end

    def exception_data(exception, force_level = nil)
      data = base_data

      data[:level] = force_level if force_level

      # parse backtrace
      if exception.backtrace.respond_to?( :map )
        frames = exception.backtrace.map { |frame|
          # parse the line
          match = frame.match(/(.*):(\d+)(?::in `([^']+)')?/)
          { :filename => match[1], :lineno => match[2].to_i, :method => match[3] }
        }
        # reverse so that the order is as ratchet expects
        frames.reverse!
      else
        frames = []
      end

      data[:body] = {
        :trace => {
          :frames => frames,
          :exception => {
            :class => exception.class.name,
            :message => exception.message
          }
        }
      }

      data[:server] = server_data

      data
    end

    def logger
      # init if not set
      unless configuration.logger
        configuration.logger = configuration.default_logger.call
      end
      configuration.logger
    end

    def write_payload(payload)
      if configuration.use_async
        @file_semaphore.synchronize {
          do_write_payload(payload)
        }
      else
        do_write_payload(payload)
      end
    end

    def do_write_payload(payload)
      logger.info '[Ratchet.io] Writing payload to file'

      begin
        unless @file
          @file = File.open(configuration.filepath, "a")
        end

        @file.puts payload
        @file.flush
        logger.info "[Ratchet.io] Success"
      rescue IOError => e
        logger.error "[Ratchet.io] Error opening/writing to file: #{e}"
      end
    end

    def send_payload(payload)
      logger.info '[Ratchet.io] Sending payload'

      uri = URI.parse(configuration.endpoint)
      http = Net::HTTP.new(uri.host, uri.port)

      if uri.scheme == 'https'
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      request = Net::HTTP::Post.new(uri.request_uri)
      request.body = payload
      response = http.request(request)

      if response.code == '200'
        logger.info '[Ratchet.io] Success'
      else
        logger.warn "[Ratchet.io] Got unexpected status code from Ratchet.io api: #{response.code}"
        logger.info "[Ratchet.io] Response: #{response.body}"
      end
    end

    def schedule_payload(payload)
      logger.info '[Ratchet.io] Scheduling payload'

      if configuration.use_async
        unless configuration.async_handler
          configuration.async_handler = method(:default_async_handler)
        end

        if configuration.write_to_file
          unless @file_semaphore
            @file_semaphore = Mutex.new
          end
        end

        configuration.async_handler.call(payload)
      else
        process_payload(payload)
      end
    end

    def build_payload(data)
      payload = {
        :access_token => configuration.access_token,
        :data => data
      }
      ActiveSupport::JSON.encode(payload)
    end

    def base_data(level = 'error')
      config = configuration
      data = {
        :timestamp => Time.now.to_i,
        :environment => config.environment,
        :level => level,
        :language => 'ruby',
        :framework => config.framework,
        :notifier => {
          :name => 'ratchetio-gem',
          :version => VERSION
        }
      }

      if defined?(SecureRandom) and SecureRandom.respond_to?(:uuid)
        data[:uuid] = SecureRandom.uuid
      end

      data
    end

    def server_data
      config = configuration

      data = {
        :host => Socket.gethostname
      }
      data[:root] = config.root.to_s if config.root
      data[:branch] = config.branch if config.branch

      data
    end

    def default_async_handler(payload)
      if defined?(GirlFriday)
        unless @queue
          @queue = GirlFriday::WorkQueue.new(nil, :size => 5) do |payload|
            process_payload(payload)
          end
        end

        @queue.push(payload)
      else
        logger.warn '[Ratchet.io] girl_friday not found to handle async call, falling back to Thread'
        Thread.new { process_payload(payload) }
      end
    end
  end
end
