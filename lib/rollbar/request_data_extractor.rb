require 'rack'
require 'tempfile'

module Rollbar
  module RequestDataExtractor
    SKIPPED_CLASSES = [Tempfile]

    def extract_person_data_from_controller(env)
      if env.has_key? 'rollbar.person_data'
        person_data = env['rollbar.person_data'] || {}
      else
        controller = env['action_controller.instance']
        person_data = controller.rollbar_person_data rescue {}
      end

      person_data
    end

    def extract_request_data_from_rack(env)
      rack_req = ::Rack::Request.new(env)

      sensitive_params = sensitive_params_list(env)
      request_params = rollbar_filtered_params(sensitive_params, rollbar_request_params(env))
      get_params = rollbar_filtered_params(sensitive_params, rollbar_get_params(rack_req))
      post_params = rollbar_filtered_params(sensitive_params, rollbar_post_params(rack_req))
      raw_body_params = rollbar_filtered_params(sensitive_params, mergeable_raw_body_params(rack_req))
      cookies = rollbar_filtered_params(sensitive_params, rollbar_request_cookies(rack_req))
      session = rollbar_filtered_params(sensitive_params, env['rack.session.options'])
      route_params = rollbar_filtered_params(sensitive_params, rollbar_route_params(env))

      params = request_params.merge(get_params).merge(post_params).merge(raw_body_params)

      data = {
        :params => params,
        :url => rollbar_url(env),
        :user_ip => rollbar_user_ip(env),
        :headers => rollbar_headers(env),
        :cookies => cookies,
        :session => session,
        :method => rollbar_request_method(env),
        :route => route_params,
      }

      if env["action_dispatch.request_id"]
        data[:request_id] = env["action_dispatch.request_id"]
      end

      data
    end

    private

    def mergeable_raw_body_params(rack_req)
      raw_body_params = rollbar_raw_body_params(rack_req)

      if raw_body_params.is_a?(Hash)
        raw_body_params
      elsif raw_body_params.is_a?(Array)
        { 'body.multi' => raw_body_params }
      else
        { 'body.value' => raw_body_params }
      end
    end

    def rollbar_request_method(env)
      env['REQUEST_METHOD'] || env[:method]
    end

    def rollbar_headers(env)
      env.keys.grep(/^HTTP_/).map do |header|
        name = header.gsub(/^HTTP_/, '').split('_').map(&:capitalize).join('-')
        if name == 'Cookie'
           {}
        elsif sensitive_headers_list.include?(name)
          { name => rollbar_scrubbed(env[header]) }
        else
          { name => env[header] }
        end
      end.inject(:merge)
    end

    def rollbar_url(env)
      forwarded_proto = env['HTTP_X_FORWARDED_PROTO'] || env['rack.url_scheme'] || ''
      scheme = forwarded_proto.split(',').first

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
    rescue
      nil
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

    def rollbar_raw_body_params(rack_req)
      correct_method = rack_req.post? || rack_req.put? || rack_req.patch?

      return {} unless correct_method
      return {} unless rack_req.env['CONTENT_TYPE'] =~ %r{application/json}i

      Rollbar::JSON.load(rack_req.body.read)
    rescue
      {}
    ensure
      rack_req.body.rewind
    end

    def rollbar_request_params(env)
      env['action_dispatch.request.parameters'] || {}
    end

    def rollbar_route_params(env)
      return {} unless defined?(Rails)

      begin
        route = ::Rails.application.routes.recognize_path(env['PATH_INFO'])

        {
          :controller => route[:controller],
          :action => route[:action],
          :format => route[:format]
        }
      rescue
        {}
      end
    end

    def rollbar_request_cookies(rack_req)
      rack_req.cookies
    rescue
      {}
    end

    def rollbar_filtered_params(sensitive_params, params)
      sensitive_params_regexp = Regexp.new(sensitive_params.map{ |val| Regexp.escape(val.to_s).to_s }.join('|'), true)

      return {} unless params

      params.to_hash.inject({}) do |result, (key, value)|
        if sensitive_params_regexp =~ key.to_s
          result[key] = rollbar_scrubbed(value)
        elsif value.is_a?(Hash)
          result[key] = rollbar_filtered_params(sensitive_params, value)
        elsif value.is_a?(Array)
          result[key] = value.map do |v|
            v.is_a?(Hash) ? rollbar_filtered_params(sensitive_params, v) : rollbar_filtered_param_value(v)
          end
        elsif skip_value?(value)
          result[key] = "Skipped value of class '#{value.class.name}'"
        else
          result[key] = rollbar_filtered_param_value(value)
        end

        result
      end
    end

    def rollbar_filtered_param_value(value)
      if ATTACHMENT_CLASSES.include?(value.class.name)
        begin
          {
            :content_type => value.content_type,
            :original_filename => value.original_filename,
            :size => value.tempfile.size
          }
        rescue
          'Uploaded file'
        end
      else
        value
      end
    end

    def sensitive_params_list(env)
      Array(Rollbar.configuration.scrub_fields) | Array(env['action_dispatch.parameter_filter'])
    end

    def sensitive_headers_list
      Rollbar.configuration.scrub_headers || []
    end

    def rollbar_scrubbed(value)
      '*' * (value.length rescue 8)
    end

    def skip_value?(value)
      SKIPPED_CLASSES.any? { |klass| value.is_a?(klass) }
    end
  end
end
