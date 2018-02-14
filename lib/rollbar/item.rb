require 'socket'
require 'forwardable'

begin
  require 'securerandom'
rescue LoadError
  nil
end

require 'rollbar/item/backtrace'
require 'rollbar/util'
require 'rollbar/encoding'
require 'rollbar/truncation'
require 'rollbar/json'

module Rollbar
  # This class represents the payload to be sent to the API.
  # It contains the logic to build the payload, trucante it
  # and dump the JSON.
  class Item
    extend Forwardable

    attr_writer :payload

    attr_reader :level
    attr_reader :message
    attr_reader :exception
    attr_reader :extra

    attr_reader :configuration
    attr_reader :scope
    attr_reader :logger
    attr_reader :notifier
    
    attr_reader :context

    def_delegators :payload, :[]

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
      @context = options[:context]
    end

    def payload
      @payload ||= build
    end

    def build
      data = build_data
      self.payload = {
        'access_token' => configuration.access_token,
        'data' => data
      }

      enforce_valid_utf8
      transform
      payload
    end

    def build_data
      data = {
        :timestamp => Time.now.to_i,
        :environment => build_environment,
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
      data[:project_package_paths] = configuration.project_gem_paths if configuration.project_gem_paths.any?
      data[:code_version] = configuration.code_version if configuration.code_version
      data[:uuid] = SecureRandom.uuid if defined?(SecureRandom) && SecureRandom.respond_to?(:uuid)

      Util.deep_merge(data, configuration.payload_options)
      Util.deep_merge(data, scope)

      # Our API doesn't allow null context values, so just delete
      # the key if value is nil.
      data.delete(:context) unless data[:context]

      data
    end

    def dump
      # Ensure all keys are strings since we can receive the payload inline or
      # from an async handler job, which can be serialized.
      stringified_payload = Util::Hash.deep_stringify_keys(payload)
      result = Truncation.truncate(stringified_payload)

      return result unless Truncation.truncate?(result)

      handle_too_large_payload(stringified_payload, result)

      nil
    end

    def handle_too_large_payload(stringified_payload, final_payload)
      original_size = Rollbar::JSON.dump(stringified_payload).bytesize
      final_size = final_payload.bytesize
      uuid = stringified_payload['data']['uuid']
      host = stringified_payload['data'].fetch('server', {})['host']

      notifier.send_failsafe("Could not send payload due to it being too large after truncating attempts. Original size: #{original_size} Final size: #{final_size}", nil, uuid, host)
      logger.error("[Rollbar] Payload too large to be sent for UUID #{uuid}: #{Rollbar::JSON.dump(payload)}")
    end

    def ignored?
      data = payload['data']

      return unless data[:person]

      person_id = data[:person][configuration.person_id_method.to_sym]
      configuration.ignored_person_ids.include?(person_id)
    end

    private

    def build_environment
      env = configuration.environment
      env = 'unspecified' if env.nil? || env.empty?

      env
    end

    def build_body
      exception ? build_backtrace_body : build_message_body
    end

    def build_backtrace_body
      backtrace = Backtrace.new(exception,
                                :message => message,
                                :extra => build_extra,
                                :configuration => configuration)

      backtrace.to_h
    end

    def build_extra
      if custom_data_method?
        Util.deep_merge(custom_data, extra || {})
      else
        extra
      end
    end

    def custom_data_method?
      !!configuration.custom_data_method
    end

    def custom_data
      
      if configuration.custom_data_method.arity == 3
        data = configuration.custom_data_method.call(message, exception, context)
      else
        data = configuration.custom_data_method.call
      end
      
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

    def build_message_body
      extra = build_extra
      result = { :body => message || 'Empty message' }
      result[:extra] = extra if extra

      { :message => result }
    end

    def server_data
      data = {
        :host => configuration.host || Socket.gethostname
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
      handlers = configuration.transform

      handlers.each do |handler|
        begin
          handler.call(transform_options)
        rescue => e
          logger.error("[Rollbar] Error calling the `transform` hook: #{e}")

          break
        end
      end
    end

    def transform_options
      {
        :level => level,
        :scope => scope,
        :exception => exception,
        :message => message,
        :extra => extra,
        :payload => payload
      }
    end
  end
end
