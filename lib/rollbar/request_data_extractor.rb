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
      sensitive_params = sensitive_params_list(env)
      request_params = rollbar_request_params(env)
      cookies = rollbar_filtered_params(sensitive_params, rollbar_request_cookies(env))
      get_params = rollbar_filtered_params(sensitive_params, rollbar_get_params(env))
      post_params = rollbar_filtered_params(sensitive_params, rollbar_post_params(env))
      session = rollbar_filtered_params(sensitive_params, env['rack.session.options'])
    
      {
        :params => get_params.merge(post_params).merge(request_params),
        :url => rollbar_url(env),
        :user_ip => rollbar_user_ip(env),
        :headers => rollbar_headers(env),
        :GET => get_params,
        :POST => post_params,
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
        { name => env[header] }
      end.inject(:merge)
    end

    def rollbar_url(env)
      scheme = env['rack.url_scheme']
      host = env['HTTP_HOST'] || env['SERVER_NAME']
      path = env['ORIGINAL_FULLPATH'] || env['REQUEST_URI']
      unless path.nil? || path.empty?
        path = '/' + path.to_s if path.to_s.slice(0, 1) != '/'
      end

      [scheme, '://', host, path].join
    end

    def rollbar_user_ip(env)
      (env['action_dispatch.remote_ip'] || env['HTTP_X_REAL_IP'] || env['HTTP_X_FORWARDED_FOR'] || env['REMOTE_ADDR']).to_s
    end

    def rollbar_request_params(env)
      route = ::Rails.application.routes.recognize_path(env['PATH_INFO']) rescue {}
      {
        :controller => route[:controller],
        :action => route[:action],
        :format => route[:format],
      }
    end

    def rollbar_get_params(env)
      rack_request(env).GET
    rescue
      {}
    end

    def rollbar_post_params(env)
      rack_request(env).POST
    rescue
      {}
    end

    def rollbar_request_cookies(env)
      rack_request(env).cookie
    rescue
      {}
    end

    def rack_request(env)
      @rack_request ||= Rack::Request.new(env)
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
