module Rollbar
  module RequestDataExtractor
    ATTACHMENT_CLASSES = %w[
      ActionDispatch::Http::UploadedFile
      Rack::Multipart::UploadedFile
    ].freeze

    def extract_person_data_from_controller(env)
      controller = env['action_controller.instance']
      person_data = controller ? controller.try(:rollbar_person_data) : {}
    end

    def extract_request_data_from_rack(env)
      rack_req = Rack::Request.new(env)
      
      sensitive_params = sensitive_params_list(env)
      request_params = rollbar_filtered_params(sensitive_params, rollbar_request_params(env))
      get_params = rollbar_filtered_params(sensitive_params, rollbar_get_params(rack_req))
      post_params = rollbar_filtered_params(sensitive_params, rollbar_post_params(rack_req))
      cookies = rollbar_filtered_params(sensitive_params, rollbar_request_cookies(rack_req))
      session = rollbar_filtered_params(sensitive_params, env['rack.session.options'])
      
      params = request_params.merge(get_params).merge(post_params)
      
      {
        :params => params,
        :url => rollbar_url(env),
        :user_ip => rollbar_user_ip(env),
        :headers => rollbar_headers(env),
        :cookies => cookies,
        :session => session,
        :method => rollbar_request_method(env)
      }
    end

    private

    def rollbar_request_method(env)
      env['REQUEST_METHOD'] || env[:method]
    end

    def rollbar_headers(env)
      env.keys.grep(/^HTTP_/).map do |header|
        name = header.gsub(/^HTTP_/, '').split('_').map(&:capitalize).join('-')
        # exclude cookies - we already include a parsed version as request_data[:cookies]
        if name == 'Cookie'
          {}
        else
          { name => env[header] }
        end
      end.inject(:merge)
    end

    def rollbar_url(env)
      scheme = env['HTTP_X_FORWARDED_PROTO'] || env['rack.url_scheme']
      
      host = env['HTTP_X_FORWARDED_HOST'] || env['HTTP_HOST'] || env['SERVER_NAME']
      path = env['ORIGINAL_FULLPATH'] || env['REQUEST_URI']
      unless path.nil? || path.empty?
        path = '/' + path.to_s if path.to_s.slice(0, 1) != '/'
      end
      
      port = env['HTTP_X_FORWARDED_PORT']
      if port && !(scheme.downcase == 'http' && port.to_i == 80) && \
                 !(scheme.downcase == 'https' && port.to_i == 443) && \
                 !(host.include? ':')
        host = host + ':' + port
      end

      [scheme, '://', host, path].join
    end

    def rollbar_user_ip(env)
      (env['action_dispatch.remote_ip'] || env['HTTP_X_REAL_IP'] || env['HTTP_X_FORWARDED_FOR'] || env['REMOTE_ADDR']).to_s
    end
    
    def rollbar_get_params(rack_req)
      rack_req.GET
    rescue
      {}
    end

    def rollbar_post_params(rack_req)
      rack_req.POST
    rescue
      {}
    end

    def rollbar_request_params(env)
      route = ::Rails.application.routes.recognize_path(env['PATH_INFO']) rescue {}
      {
        :controller => route[:controller],
        :action => route[:action],
        :format => route[:format],
      }.merge(env['action_dispatch.request.parameters'] || {})
    end
    
    def rollbar_request_cookies(rack_req)
      rack_req.cookies
    rescue
      {}
    end

    def rollbar_filtered_params(sensitive_params, params)
      if params.nil?
        {}
      else
        params.to_hash.inject({}) do |result, (key, value)|
          if sensitive_params.include?(key.to_sym)
            result[key] = '*' * (value.length rescue 8)
          elsif value.is_a?(Hash)
            result[key] = rollbar_filtered_params(sensitive_params, value)
          elsif ATTACHMENT_CLASSES.include?(value.class.name)
            result[key] = {
              :content_type => value.content_type,
              :original_filename => value.original_filename,
              :size => value.tempfile.size
            } rescue 'Uploaded file'
          else
            result[key] = value
          end
          result
        end
      end
    end

    def sensitive_params_list(env)
      Rollbar.configuration.scrub_fields |= Array(env['action_dispatch.parameter_filter'])
    end
  end
end
