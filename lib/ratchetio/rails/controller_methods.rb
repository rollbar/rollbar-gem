module Ratchetio
  module Rails
    module ControllerMethods
    
      def ratchetio_request_data
        { 
          :params => params.to_hash,
          :url => ratchetio_request_url,
          :user_ip => ratchetio_user_ip,
          :headers => ratchetio_request_headers,
          :GET => request.GET.to_hash,
          # leaving out POST for now
          :method => request.method,
        }
      end

      private

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
        real_ip = request.env["HTTP_X_REAL_IP"]
        if real_ip
          return real_ip
        end
        forwarded_for = request.env["HTTP_X_FORWARDED_FOR"]
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

    end
  end
end
