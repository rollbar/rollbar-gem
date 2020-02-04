require 'rack'
require 'tempfile'

require 'rollbar/scrubbers'
require 'rollbar/scrubbers/url'
require 'rollbar/scrubbers/params'
require 'rollbar/util/ip_obfuscator'
require 'rollbar/util/ip_anonymizer'
require 'rollbar/json'

module Rollbar
  module RequestDataExtractor
    ALLOWED_HEADERS_REGEX = /^HTTP_|^CONTENT_TYPE$|^CONTENT_LENGTH$/.freeze
    ALLOWED_BODY_PARSEABLE_METHODS = %w[POST PUT PATCH DELETE].freeze

    def extract_person_data_from_controller(env)
      if env.key?('rollbar.person_data')
        person_data = env['rollbar.person_data'] || {}
      else
        controller = env['action_controller.instance']
        person_data = begin
                        controller.rollbar_person_data
                      rescue StandardError
                        {}
                      end
      end

      person_data
    end

    def extract_request_data_from_rack(env)
      rack_req = ::Rack::Request.new(env)
      sensitive_params = sensitive_params_list(env)

      get_params = scrub_params(rollbar_get_params(rack_req), sensitive_params)
      post_params = scrub_params(rollbar_post_params(rack_req), sensitive_params)
      raw_body_params = scrub_params(mergeable_raw_body_params(rack_req), sensitive_params)
      cookies = scrub_params(rollbar_request_cookies(rack_req), sensitive_params)
      session = scrub_params(rollbar_request_session(env), sensitive_params)
      route_params = scrub_params(rollbar_route_params(env), sensitive_params)

      url = scrub_url(rollbar_url(env), sensitive_params)

      data = {
        :url => url,
        :params => route_params,
        :GET => get_params,
        :POST => post_params,
        :body => Rollbar::JSON.dump(raw_body_params),
        :user_ip => rollbar_user_ip(env),
        :headers => rollbar_headers(env),
        :cookies => cookies,
        :session => session,
        :method => rollbar_request_method(env)
      }

      data[:request_id] = env['action_dispatch.request_id'] if env['action_dispatch.request_id']

      data
    end

    def scrub_url(url, sensitive_params)
      options = {
        :url => url,
        :scrub_fields => Array(Rollbar.configuration.scrub_fields) + sensitive_params,
        :scrub_user => Rollbar.configuration.scrub_user,
        :scrub_password => Rollbar.configuration.scrub_password,
        :randomize_scrub_length => Rollbar.configuration.randomize_scrub_length,
        :whitelist => Rollbar.configuration.scrub_whitelist
      }

      Rollbar::Scrubbers::URL.call(options)
    end

    def scrub_params(params, sensitive_params)
      options = {
        :params => params,
        :config => Rollbar.configuration.scrub_fields,
        :extra_fields => sensitive_params,
        :whitelist => Rollbar.configuration.scrub_whitelist
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
      env.keys.grep(ALLOWED_HEADERS_REGEX).map do |header|
        name = header.gsub(/^HTTP_/, '').split('_').map(&:capitalize).join('-')
        if name == 'Cookie'
          {}
        elsif sensitive_headers_list.include?(name)
          { name => Rollbar::Scrubbers.scrub_value(env[header]) }
        elsif name == 'X-Forwarded-For' && !Rollbar.configuration.collect_user_ip
          {}
        elsif name == 'X-Forwarded-For' && Rollbar.configuration.collect_user_ip && Rollbar.configuration.anonymize_user_ip
          ips = env[header].sub(' ', '').split(',')
          ips = ips.map { |ip| Rollbar::Util::IPAnonymizer.anonymize_ip(ip) }
          { name => ips.join(', ') }
        elsif name == 'X-Real-Ip' && !Rollbar.configuration.collect_user_ip
          {}
        elsif name == 'X-Real-Ip' && Rollbar.configuration.collect_user_ip && Rollbar.configuration.anonymize_user_ip
          { name => Rollbar::Util::IPAnonymizer.anonymize_ip(env[header]) }
        else
          { name => env[header] }
        end
      end.inject(:merge)
    end

    def rollbar_url(env)
      forwarded_proto = env['HTTP_X_FORWARDED_PROTO'] || env['rack.url_scheme'] || ''
      scheme = forwarded_proto.split(',').first

      host = env['HTTP_X_FORWARDED_HOST'] || env['HTTP_HOST'] || env['SERVER_NAME'] || ''
      host = host.split(',').first.strip unless host.empty?

      path = env['ORIGINAL_FULLPATH'] || env['REQUEST_URI']
      unless path.nil? || path.empty?
        path = '/' + path.to_s if path.to_s.slice(0, 1) != '/'
      end

      port = env['HTTP_X_FORWARDED_PORT']
      if port && !(!scheme.nil? && scheme.casecmp('http').zero? && port.to_i == 80) && \
         !(!scheme.nil? && scheme.casecmp('https').zero? && port.to_i == 443) && \
         !(host.include? ':')
        host = host + ':' + port
      end

      [scheme, '://', host, path].join
    end

    def rollbar_user_ip(env)
      return nil unless Rollbar.configuration.collect_user_ip

      user_ip_string = (env['action_dispatch.remote_ip'] || env['HTTP_X_REAL_IP'] || x_forwarded_for_client(env['HTTP_X_FORWARDED_FOR']) || env['REMOTE_ADDR']).to_s

      user_ip_string = Rollbar::Util::IPAnonymizer.anonymize_ip(user_ip_string)

      Rollbar::Util::IPObfuscator.obfuscate_ip(user_ip_string)
    rescue StandardError
      nil
    end

    def x_forwarded_for_client(header_value)
      return nil unless header_value

      ips = header_value.split(',').map(&:strip)

      find_not_private_ip(ips)
    end

    def find_not_private_ip(ips)
      ips.detect do |ip|
        octets = ip.match(/^(\d{1,3}).(\d{1,3}).(\d{1,3}).(\d{1,3})$/)[1, 4].map(&:to_i)

        is_private = (octets[0] == 10) ||
                     ((octets[0] == 172) && (octets[1] >= 16) && (octets[1] <= 31)) ||
                     ((octets[0] == 192) && (octets[1] == 168))

        !is_private
      end
    end

    def rollbar_get_params(rack_req)
      rack_req.GET
    rescue StandardError
      {}
    end

    def rollbar_post_params(rack_req)
      rack_req.POST
    rescue StandardError
      {}
    end

    def rollbar_raw_body_params(rack_req)
      correct_method = ALLOWED_BODY_PARSEABLE_METHODS.include?(rack_req.request_method)

      return {} unless correct_method
      return {} unless json_request?(rack_req)

      raw_body = rack_req.body.read
      begin
        Rollbar::JSON.load(raw_body)
      rescue StandardError
        raw_body
      end
    rescue StandardError
      {}
    ensure
      rack_req.body.rewind
    end

    def json_request?(rack_req)
      json_regex = /\bjson\b/

      !!(rack_req.env['CONTENT_TYPE'] =~ json_regex)
    end

    def rollbar_route_params(env)
      return {} unless defined?(Rails)

      begin
        environment = { :method => rollbar_request_method(env) }

        # recognize_path() will return the controller, action
        # route params (if any)and format (if defined)
        ::Rails.application.routes.recognize_path(env['PATH_INFO'],
                                                  environment)
      rescue StandardError
        {}
      end
    end

    def rollbar_request_session(env)
      session = env.fetch('rack.session', {})

      session.to_hash
    rescue StandardError
      {}
    end

    def rollbar_request_cookies(rack_req)
      rack_req.cookies
    rescue StandardError
      {}
    end

    def sensitive_params_list(env)
      Array(env['action_dispatch.parameter_filter'])
    end

    def sensitive_headers_list
      return [] unless Rollbar.configuration.scrub_headers && Rollbar.configuration.scrub_headers.is_a?(Array)

      # Normalize into the expected matching format
      Rollbar.configuration.scrub_headers.map do |header|
        header.split(/[-_]/).map(&:capitalize).join('-').gsub(/^Http-/, '')
      end
    end
  end
end
