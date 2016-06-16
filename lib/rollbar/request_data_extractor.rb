require 'rack'
require 'tempfile'

require 'rollbar/scrubbers'
require 'rollbar/scrubbers/url'
require 'rollbar/scrubbers/params'
require 'rollbar/util/ip_obfuscator'

module Rollbar
  module RequestDataExtractor
    def extract_person_data_from_controller(env)
      if env.has_key?('rollbar.person_data')
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
      request_params = scrub_params(rollbar_request_params(env), sensitive_params)
      get_params = scrub_params(rollbar_get_params(rack_req), sensitive_params)
      post_params = scrub_params(rollbar_post_params(rack_req), sensitive_params)
      raw_body_params = scrub_params(mergeable_raw_body_params(rack_req), sensitive_params)
      cookies = scrub_params(rollbar_request_cookies(rack_req), sensitive_params)
      session = scrub_params(rollbar_request_session(rack_req), sensitive_params)
      route_params = scrub_params(rollbar_route_params(env), sensitive_params)

      url = scrub_url(rollbar_url(env), sensitive_params)
      params = request_params.merge(get_params).merge(post_params).merge(raw_body_params)

      data = {
        :params => params,
        :url => url,
        :user_ip => rollbar_user_ip(env),
        :headers => rollbar_headers(env),
        :cookies => cookies,
        :session => session,
        :method => rollbar_request_method(env),
        :route => route_params
      }

      if env['action_dispatch.request_id']
        data[:request_id] = env['action_dispatch.request_id']
      end

      data
    end

    def scrub_url(url, sensitive_params)
      options = {
        :url => url,
        :scrub_fields => Array(Rollbar.configuration.scrub_fields) + sensitive_params,
        :scrub_user => Rollbar.configuration.scrub_user,
        :scrub_password => Rollbar.configuration.scrub_password,
        :randomize_scrub_length => Rollbar.configuration.randomize_scrub_length
      }

      Rollbar::Scrubbers::URL.call(options)
    end

    def scrub_params(params, sensitive_params)
      options = {
        :params => params,
        :config => Rollbar.configuration.scrub_fields,
        :extra_fields => sensitive_params
      }
      Rollbar::Scrubbers::Params.call(options)
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
          { name => Rollbar::Scrubbers.scrub_value(env[header]) }
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
      user_ip_string = (env['action_dispatch.remote_ip'] || env['HTTP_X_REAL_IP'] || env['HTTP_X_FORWARDED_FOR'] || env['REMOTE_ADDR']).to_s

      Rollbar::Util::IPObfuscator.obfuscate_ip(user_ip_string)
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
      return {} unless json_request?(rack_req)

      Rollbar::JSON.load(rack_req.body.read)
    rescue
      {}
    ensure
      rack_req.body.rewind
    end

    def json_request?(rack_req)
      !!(rack_req.env['CONTENT_TYPE'] =~ %r{application/json} ||
         rack_req.env['ACCEPT'] =~ /\bjson\b/)
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

    def rollbar_request_session(rack_req)
      session = rack_req.session

      session.to_hash
    rescue
      {}
    end

    def rollbar_request_cookies(rack_req)
      rack_req.cookies
    rescue
      {}
    end

    def sensitive_params_list(env)
      Array(env['action_dispatch.parameter_filter'])
    end

    def sensitive_headers_list
      Rollbar.configuration.scrub_headers || []
    end
  end
end
