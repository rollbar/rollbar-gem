require 'socket'
require 'forwardable'

begin
  require 'securerandom'
rescue LoadError
end

require 'rollbar/util'
require 'rollbar/encoding'

module Rollbar
  class Item
    extend Forwardable

    attr_writer :payload

    attr_reader :level
    attr_reader :message
    attr_reader :exception
    attr_accessor :extra

    attr_reader :configuration
    attr_reader :scope
    attr_reader :logger
    attr_reader :notifier
    attr_accessor :ignored

    private :ignored=

    def_delegators :payload, :[]

    alias_method :ignored?, :ignored

    class << self
      def build_with(payload, options = {})
        new(options).tap do |item|
          item.payload = payload
        end
      end
    end

    def initialize(options)
      @level = options[:level]
      @message = options[:message]
      @exception = options[:exception]
      @extra = options[:extra]
      @configuration = options[:configuration]
      @logger = options[:logger]
      @scope = options[:scope]
      @payload = nil
      @notifier = options[:notifier]
      @ignored = false
    end

    def payload
      @payload ||= build
    end

    def build
      environment = configuration.environment
      environment = 'unspecified' if environment.nil? || environment.empty?

      data = {
        :timestamp => Time.now.to_i,
        :environment => environment,
        :level => level,
        :language => 'ruby',
        :framework => configuration.framework,
        :server => server_data,
        :notifier => {
          :name => 'rollbar-gem',
          :version => VERSION
        },
        :body => build_body
      }

      data[:project_package_paths] = configuration.project_gem_paths if configuration.project_gem_paths
      data[:code_version] = configuration.code_version if configuration.code_version
      data[:uuid] = SecureRandom.uuid if defined?(SecureRandom) && SecureRandom.respond_to?(:uuid)

      Util.deep_merge(data, configuration.payload_options)
      Util.deep_merge(data, scope)

      # Our API doesn't allow null context values, so just delete
      # the key if value is nil.
      data.delete(:context) unless data[:context]

      if data[:person]
        person_id = data[:person][configuration.person_id_method.to_sym]
        self.ignored = configuration.ignored_person_ids.include?(person_id)
      end

      self.payload = {
        'access_token' => configuration.access_token,
        'data' => data
      }

      enforce_valid_utf8
      transform

      payload
    end

    def dump
      # Ensure all keys are strings since we can receive the payload inline or
      # from an async handler job, which can be serialized.
      stringified_payload = Util::Hash.deep_stringify_keys(payload)
      result = Truncation.truncate(stringified_payload)
      return result unless Truncation.truncate?(result)

      original_size = Rollbar::JSON.dump(payload).bytesize
      final_size = result.bytesize
      notifier.send_failsafe("Could not send payload due to it being too large after truncating attempts. Original size: #{original_size} Final size: #{final_size}", nil)
      logger.error("[Rollbar] Payload too large to be sent: #{Rollbar::JSON.dump(payload)}")

      nil
    end

    private

    def build_body
      self.extra = Util.deep_merge(custom_data, extra || {}) if custom_data_method?

      if exception
        build_body_exception
      else
        build_body_message
      end
    end

    def custom_data_method?
      !!configuration.custom_data_method
    end

    def custom_data
      data = configuration.custom_data_method.call
      Rollbar::Util.deep_copy(data)
    rescue => e
      return {} if configuration.safely?

      report_custom_data_error(e)
    end

    def report_custom_data_error(e)
      data = notifier.safely.error(e)

      return {} unless data.is_a?(Hash) && data[:uuid]

      uuid_url = Util.uuid_rollbar_url(data, configuration)

      { :_error_in_custom_data_method => uuid_url }
    end

    def build_body_exception
      traces = trace_chain

      traces[0][:exception][:description] = message if message
      traces[0][:extra] = extra if extra

      if traces.size > 1
        { :trace_chain => traces }
      elsif traces.size == 1
        { :trace => traces[0] }
      end
    end

    def trace_data(current_exception)
      frames = exception_backtrace(current_exception).map do |frame|
        # parse the line
        match = frame.match(/(.*):(\d+)(?::in `([^']+)')?/)

        if match
          { :filename => match[1], :lineno => match[2].to_i, :method => match[3] }
        else
          { :filename => "<unknown>", :lineno => 0, :method => frame }
        end
      end

      # reverse so that the order is as rollbar expects
      frames.reverse!

      {
        :frames => frames,
        :exception => {
          :class => current_exception.class.name,
          :message => current_exception.message
        }
      }
    end

    # Returns the backtrace to be sent to our API. There are 3 options:
    #
    # 1. The exception received has a backtrace, then that backtrace is returned.
    # 2. configuration.populate_empty_backtraces is disabled, we return [] here
    # 3. The user has configuration.populate_empty_backtraces is enabled, then:
    #
    # We want to send the caller as backtrace, but the first lines of that array
    # are those from the user's Rollbar.error line until this method. We want
    # to remove those lines.
    def exception_backtrace(current_exception)
      return current_exception.backtrace if current_exception.backtrace.respond_to?( :map )
      return [] unless configuration.populate_empty_backtraces

      caller_backtrace = caller
      caller_backtrace.shift while caller_backtrace[0].include?(rollbar_lib_gem_dir)
      caller_backtrace
    end

    def rollbar_lib_gem_dir
      Gem::Specification.find_by_name('rollbar').gem_dir + '/lib'
    end

    def trace_chain
      exception
      traces = [trace_data(exception)]
      visited = [exception]

      current_exception = exception

      while current_exception.respond_to?(:cause) && (cause = current_exception.cause) && cause.is_a?(Exception) && !visited.include?(cause)
        traces << trace_data(cause)
        visited << cause
        current_exception = cause
      end

      traces
    end

    def build_body_message
      result = { :body => message || 'Empty message'}
      result[:extra] = extra if extra

      { :message => result }
    end

    def server_data
      data = {
        :host => Socket.gethostname
      }
      data[:root] = configuration.root.to_s if configuration.root
      data[:branch] = configuration.branch if configuration.branch
      data[:pid] = Process.pid

      data
    end

    def enforce_valid_utf8
      Util.enforce_valid_utf8(payload)
    end

    def transform
      options = {
        :level => level,
        :scope => scope,
        :exception => exception,
        :message => message,
        :extra => extra,
        :payload => payload
      }
      handlers = configuration.transform

      handlers.each do |handler|
        begin
          handler.call(options)
        rescue => e
          logger.error("[Rollbar] Error calling the `transform` hook: #{e}")

          break
        end
      end
    end
  end
end
