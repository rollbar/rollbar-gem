require 'rollbar/request_data_extractor'
require 'rollbar/util'

module Rollbar
  module Rails
    module ControllerMethods
      include RequestDataExtractor

      def rollbar_person_data
        return {} if Rollbar::Util.method_in_stack_twice(:rollbar_person_data, __FILE__)

        config = Rollbar.configuration
        user = send(config.person_method)
        return {} unless user

        # include id, username, email if non-empty
        {
          :id => (begin
            user.send(config.person_id_method) if config.person_id_method
          rescue StandardError
            nil
          end),
          :username => (begin
            user.send(config.person_username_method) if config.person_username_method
          rescue StandardError
            nil
          end),
          :email => (begin
            user.send(config.person_email_method) if config.person_email_method
          rescue StandardError
            nil
          end)
        }
      rescue NameError
        {}
      end

      def rollbar_request_data
        extract_request_data_from_rack(request.env)
      end

      # for backwards compatabilty with the old ratchetio-gem
      def ratchetio_person_data
        rollbar_person_data
      end

      # for backwards compatabilty with the old ratchetio-gem
      def ratchetio_request_data
        rollbar_request_data
      end
    end
  end
end
