require 'rack'
require 'rack/response'

require 'rollbar/request_data_extractor'
require 'rollbar/util'

module Rollbar
  module Middleware
    # Middleware to inject the rollbar.js snippet into a 200 html response
    class Js
      include Rollbar::RequestDataExtractor

      attr_reader :app
      attr_reader :config

      JS_IS_INJECTED_KEY = 'rollbar.js_is_injected'
      SNIPPET = File.read(File.expand_path('../../../../data/rollbar.snippet.js', __FILE__))

      def initialize(app, config)
        @app = app
        @config = config
      end

      def call(env)
        app_result = app.call(env)

        begin
          return app_result unless add_js?(env, app_result[1])

          response_string = add_js(env, app_result[2])
          build_response(env, app_result, response_string)
        rescue => e
          Rollbar.log_error("[Rollbar] Rollbar.js could not be added because #{e} exception")

          app_result
        end
      end

      def enabled?
        !!config[:enabled]
      end

      def add_js?(env, headers)
        enabled? && !env[JS_IS_INJECTED_KEY] &&
          html?(headers) && !attachment?(headers) && !streaming?(env)
      end

      def html?(headers)
        headers['Content-Type'] && headers['Content-Type'].include?('text/html')
      end

      def attachment?(headers)
        headers['Content-Disposition'].to_s.include?('attachment')
      end

      def streaming?(env)
        return false unless defined?(ActionController::Live)

        env['action_controller.instance'].class.included_modules.include?(ActionController::Live)
      end

      def add_js(env, response)
        body = join_body(response)
        close_old_response(response)

        return nil unless body

        insert_after_idx = find_insertion_point(body)
        return nil unless insert_after_idx

        build_body_with_js(env, body, insert_after_idx)
      rescue => e
        Rollbar.log_error("[Rollbar] Rollbar.js could not be added because #{e} exception")
        nil
      end

      def build_response(env, app_result, response_string)
        return app_result unless response_string

        env[JS_IS_INJECTED_KEY] = true
        response = ::Rack::Response.new(response_string, app_result[0],
                                        app_result[1])

        response.finish
      end

      def build_body_with_js(env, body, head_open_end)
        return body unless head_open_end

        body[0..head_open_end] << config_js_tag(env) << snippet_js_tag(env) <<
          body[head_open_end + 1..-1]
      end

      def find_insertion_point(body)
        find_end_after_regex(body, /<meta\s*charset=/i) ||
          find_end_after_regex(body, /<meta\s*http-equiv="Content-Type"/i) ||
          find_end_after_regex(body, /<head\W/i)
      end

      def find_end_after_regex(body, regex)
        open_idx = body.index(regex)
        body.index('>', open_idx) if open_idx
      end

      def join_body(response)
        response.to_enum.reduce('') do |acc, fragment|
          acc << fragment.to_s
          acc
        end
      end

      def close_old_response(response)
        response.close if response.respond_to?(:close)
      end

      def config_js_tag(env)
        js_config = Rollbar::Util.deep_copy(config[:options])

        add_person_data(js_config, env)

        script_tag("var _rollbarConfig = #{js_config.to_json};", env)
      end

      def add_person_data(js_config, env)
        person_data = extract_person_data_from_controller(env)

        return if person_data && person_data.empty?

        js_config[:payload] ||= {}
        js_config[:payload][:person] = person_data if person_data
      end

      def snippet_js_tag(env)
        script_tag(js_snippet, env)
      end

      def js_snippet
        SNIPPET
      end

      def script_tag(content, env)
        if append_nonce?
          nonce = ::SecureHeaders.content_security_policy_script_nonce(::Rack::Request.new(env))
          script_tag_content = "\n<script type=\"text/javascript\" nonce=\"#{nonce}\">#{content}</script>"
        else
          script_tag_content = "\n<script type=\"text/javascript\">#{content}</script>"
        end

        html_safe_if_needed(script_tag_content)
      end

      def html_safe_if_needed(string)
        string = string.html_safe if string.respond_to?(:html_safe)
        string
      end

      def append_nonce?
        defined?(::SecureHeaders) && ::SecureHeaders.respond_to?(:content_security_policy_script_nonce) &&
          defined?(::SecureHeaders::Configuration) &&
          !::SecureHeaders::Configuration.dup.csp.opt_out? &&
          !::SecureHeaders::Configuration.dup.csp[:script_src].to_a.include?("'unsafe-inline'")
      end
    end
  end
end
