require 'rollbar/request_data_extractor'
require 'rollbar/util'

module Rollbar
  module Rails
    module ControllerMethods
      include RequestDataExtractor

      def rollbar_person_data
        user = nil
        unless Rollbar::Util.method_in_stack_twice(:rollbar_person_data, __FILE__)
          user = send(Rollbar.configuration.person_method)
        end

        # include id, username, email if non-empty
        if user
          {
            :id => (begin
              user.send(Rollbar.configuration.person_id_method)
            rescue StandardError
              nil
            end),
            :username => (begin
              user.send(Rollbar.configuration.person_username_method)
            rescue StandardError
              nil
            end),
            :email => (begin
              user.send(Rollbar.configuration.person_email_method)
            rescue StandardError
              nil
            end)
          }
        else
          {}
        end
      rescue NoMethodError, NameError
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
