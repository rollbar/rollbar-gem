module Ratchetio
  module Rails
    module ControllerMethods
    
      def ratchetio_request_data
        { 
          :params => ratchetio_filter_params(params),
          :url => ratchetio_request_url,
          :user_ip => ratchetio_user_ip,
          :headers => ratchetio_request_headers,
          :GET => request.GET.to_hash,
          # leaving out POST for now
          :session => ratchetio_session_data,
          :method => request.method,
        }
      end

      def ratchetio_person_data
        user = send(Ratchetio.configuration.person_method)
        # include id, username, email if non-empty
        if user
          { 
            :id => user.send(Ratchetio.configuration.person_id_method) rescue nil,
            :username => user.send(Ratchetio.configuration.person_username_method) rescue nil,
            :email => user.send(Ratchetio.configuration.person_email_method) rescue nil
          }
        else
          {}
        end
      rescue NoMethodError, NameError
        {}
      end

      private

      def ratchetio_filter_params(params)
        filtered = {}
        params.to_hash.each_pair do |k,v|
          if v.is_a? ActionDispatch::Http::UploadedFile
            # only save content_type, original_filename, and length
            begin
              filtered[k] = { 
                :content_type => v.content_type, 
                :original_filename => v.original_filename, 
                :size => v.tempfile.size 
              }
            rescue
              filtered[k] = 'Uploaded file'
            end
          elsif v.is_a? Hash
            filtered[k] = ratchetio_filter_params v
          else
            filtered[k] = v
          end
        end
        filtered
      end

      def ratchetio_request_url
        url = "#{request.protocol}#{request.host}"
        unless [80, 443].include?(request.port)
          url << ":#{request.port}"
        end
        url << request.fullpath
        url
      end

      def ratchetio_user_ip
        # priority: X-Real-Ip, then X-Forwarded-For, then request.remote_ip
        real_ip = request.env['HTTP_X_REAL_IP']
        if real_ip
          return real_ip
        end
        forwarded_for = request.env['HTTP_X_FORWARDED_FOR']
        if forwarded_for
          return forwarded_for
        end
        request.remote_ip
      end

      def ratchetio_request_headers
        headers = {}
        request.env.each_pair do |k,v|
          if k.match(/^HTTP_/)
            # convert HTTP_CONTENT_TYPE to Content-Type, etc.
            name = k.split("_", 2)[1].sub("_", "-").split(/(\W)/).map(&:capitalize).join
            headers[name] = v
          end
        end
        headers
      end

      def ratchetio_session_data
        if session.respond_to?(:to_hash)
          session.to_hash
        else
          session.data
        end
      end

    end
  end
end
