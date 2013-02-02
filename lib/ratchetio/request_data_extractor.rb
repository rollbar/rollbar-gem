module Ratchetio
  module RequestDataExtractor
    ATTACHMENT_CLASSES = %w[
      ActionDispatch::Http::UploadedFile
      Rack::Multipart::UploadedFile
    ].freeze

    def extract_person_data_from_controller(env)
      controller = env['action_controller.instance']
      person_data = controller ? controller.try(:ratchetio_person_data) : {}
    end

    def extract_request_data_from_rack(env)
      sensitive_params = sensitive_params_list(env)
      request_params = ratchetio_request_params(env)
      cookies = ratchetio_filtered_params(sensitive_params, ratchetio_request_cookies(env))
      get_params = ratchetio_filtered_params(sensitive_params, ratchetio_get_params(env))
      post_params = ratchetio_filtered_params(sensitive_params, ratchetio_post_params(env))
    
      {
        :params => get_params.merge(post_params).merge(request_params),
        :url => ratchetio_url(env),
        :user_ip => ratchetio_user_ip(env),
        :headers => ratchetio_headers(env),
        :GET => get_params,
        :POST => post_params,
        :cookies => cookies,
        :session => env['rack.session.options'],
        :method => ratchetio_request_method(env)
      }
    end

    private

    def ratchetio_request_method(env)
      env['REQUEST_METHOD'] || env[:method]
    end

    def ratchetio_headers(env)
      env.keys.grep(/^HTTP_/).map do |header|
        name = header.gsub(/^HTTP_/, '').split('_').map(&:capitalize).join('-')
        { name => env[header] }
      end.inject(:merge)
    end

    def ratchetio_url(env)
      scheme = env['rack.url_scheme']
      host = env['HTTP_HOST'] || env['SERVER_NAME']
      path = env['ORIGINAL_FULLPATH'] || env['REQUEST_URI']
      unless path.nil? || path.empty?
        path = '/' + path.to_s if path.to_s.slice(0, 1) != '/'
      end

      [scheme, '://', host, path].join
    end

    def ratchetio_user_ip(env)
      (env['action_dispatch.remote_ip'] || env['HTTP_X_REAL_IP'] || env['HTTP_X_FORWARDED_FOR'] || env['REMOTE_ADDR']).to_s
    end

    def ratchetio_request_params(env)
      route = ::Rails.application.routes.recognize_path(env['PATH_INFO']) rescue {}
      {
        :controller => route[:controller],
        :action => route[:action],
        :format => route[:format],
      }
    end

    def ratchetio_get_params(env)
      rack_request(env).GET
    rescue
      {}
    end

    def ratchetio_post_params(env)
      rack_request(env).POST
    rescue
      {}
    end

    def ratchetio_request_cookies(env)
      rack_request(env).cookie
    rescue
      {}
    end

    def rack_request(env)
      @rack_request ||= Rack::Request.new(env)
    end

    def ratchetio_filtered_params(sensitive_params, params)
      params.inject({}) do |result, (key, value)|
        if sensitive_params && sensitive_params.include?(key.to_sym)
          result[key] = '*' * (value.length rescue 8)
        elsif value.is_a?(Hash)
          result[key] = ratchetio_filtered_params(sensitive_params, value)
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

    def sensitive_params_list(env)
      Ratchetio.configuration.scrub_fields |= Array(env['action_dispatch.parameter_filter'])
    end
  end
end
