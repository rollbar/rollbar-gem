require 'rollbar/request_data_extractor'

module Rollbar
  # ActionCable rescues every exception raised by a channel or a connection and
  # only logs it, so nothing reaches Rack or the Rails error reporter. Report
  # those exceptions before ActionCable swallows them.
  module ActionCable
    extend RequestDataExtractor

    def self.patch!
      ::ActionCable::Connection::Base.send(:prepend, Connection)
      ::ActionCable::Connection::Subscriptions.send(:prepend, Subscriptions)
    end

    def self.report(exception, connection, context)
      Rollbar.scope(
        :request => proc { extract_request_data_from_rack(connection.env) },
        :context => context
      ).error(exception, :use_exception_level_filters => true)
    end

    # Subscriptions#execute_command offers command errors to the connection's
    # rescue_from handlers (Rails >= 6.1) before logging them. Leave the ones a
    # handler takes care of to that handler, like rescue_from in a controller.
    def self.report_command_error(exception, connection, data)
      return if rescued_by_connection?(exception, connection)

      report(exception, connection, command_context(data))
    end

    def self.rescued_by_connection?(exception, connection)
      return false unless connection.respond_to?(:handler_for_rescue)

      # Like rescue_with_handler, fall back to handlers for the cause.
      visited = []
      while exception && !visited.include?(exception)
        return true if connection.handler_for_rescue(exception)

        visited << exception
        exception = exception.cause
      end

      false
    end

    # "ChatChannel#subscribe", "ChatChannel#speak", "ChatChannel#unsubscribe"
    def self.command_context(data)
      channel = ActiveSupport::JSON.decode(data['identifier'])['channel']
      action = data['command']
      if action == 'message'
        action = ActiveSupport::JSON.decode(data['data'])['action'].presence || 'receive'
      end

      "#{channel}##{action}"
    rescue StandardError
      nil
    end

    # Errors from the subscribe, unsubscribe and message commands a client sends:
    # a channel's #subscribed, #unsubscribed and actions.
    module Subscriptions
      def add(data)
        report_errors_to_rollbar(data) { super }
      end

      def remove(data)
        report_errors_to_rollbar(data) { super }
      end

      def perform_action(data)
        report_errors_to_rollbar(data) { super }
      end

      private

      def report_errors_to_rollbar(data)
        yield
      rescue Exception => e # rubocop:disable Lint/RescueException
        Rollbar::ActionCable.report_command_error(e, connection, data)
        raise
      end
    end

    # Errors raised while a connection opens or closes: #connect, #disconnect,
    # and the #unsubscribed callbacks run when the client goes away.
    module Connection
      private

      def handle_open
        super
      rescue Exception => e # rubocop:disable Lint/RescueException
        Rollbar::ActionCable.report(e, self, "#{self.class.name}#connect")
        raise
      end

      def handle_close
        super
      rescue Exception => e # rubocop:disable Lint/RescueException
        Rollbar::ActionCable.report(e, self, "#{self.class.name}#disconnect")
        raise
      end
    end
  end
end
