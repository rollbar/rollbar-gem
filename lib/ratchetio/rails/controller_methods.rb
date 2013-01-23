module Ratchetio
  module Rails
    module ControllerMethods
      include RequestDataExtractor

      def ratchetio_person_data
        user = send(Ratchetio.configuration.person_method)
        # include id, username, email if non-empty
        if user
          {
            :id => (user.send(Ratchetio.configuration.person_id_method) rescue nil),
            :username => (user.send(Ratchetio.configuration.person_username_method) rescue nil),
            :email => (user.send(Ratchetio.configuration.person_email_method) rescue nil)
          }
        else
          {}
        end
      rescue NoMethodError, NameError
        {}
      end

      def ratchetio_request_data
        extract_request_data_from_rack(request.env)
      end

    end
  end
end
