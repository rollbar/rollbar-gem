require 'net/https'
require 'socket'
require 'uri'

require 'ratchetio/version'
require 'ratchetio/configuration'
require 'ratchetio/railtie' if defined?(Rails)
require 'ratchetio/goalie' if defined?(Goalie)

module Ratchetio
  class << self
    attr_writer :configuration
    
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

    # Returns the configuration object.
    #
    # @return [Ratchetio::Configuration] The configuration object
    def configuration
      @configuration ||= Configuration.new
    end

    # Reports an exception to Ratchet.io
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
      unless configuration.enabled
        return
      end

      filtered_level = configuration.exception_level_filters[exception.class.name]
      if filtered_level == 'ignore'
        # ignored - do nothing
        return
      end

      data = exception_data(exception, filtered_level)
      data[:request] = request_data if request_data
      data[:person] = person_data if person_data

      payload = build_payload(data)
      send_payload(payload)
    rescue => e
      logger.error "[Ratchet.io] Error reporting exception to Ratchet.io: #{e}"
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
      send_payload(payload)
    rescue => e
      logger.error "[Ratchet.io] Error reporting message to Ratchet.io: #{e}"
    end

    private

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
      frames = exception.backtrace.map { |frame|
        # parse the line
        match = frame.match(/(.*):(\d+)(?::in `([^']+)')?/)
        { :filename => match[1], :lineno => match[2].to_i, :method => match[3] }
      }
      # reverse so that the order is as ratchet expects
      frames.reverse!

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

    def send_payload(payload)
      logger.info '[Ratchet.io] Sending payload'

      uri = URI.parse(configuration.endpoint)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

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

    def build_payload(data)
      payload = {
        :access_token => configuration.access_token,
        :data => data
      }
      ActiveSupport::JSON.encode(payload)
    end

    def base_data(level = 'error')
      config = configuration
      {
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
  
  end
end
