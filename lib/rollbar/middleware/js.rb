require 'rack'
require 'rack/response'

module Rollbar
  module Middleware
    # Middleware to inject the rollbar.js snippet into a 200 html response
    class Js
      attr_reader :app
      attr_reader :config

      JS_IS_INJECTED_KEY = 'rollbar.js_is_injected'
      SNIPPET = File.read(File.expand_path('../../../../data/rollbar.snippet.js', __FILE__))

      def initialize(app, config)
        @app = app
        @config = config
      end

      def call(env)
        result = app.call(env)

        begin
          return result unless add_js?(env, result[0], result[1])

          response_string = add_js(env, result[2])
          build_response(env, result, response_string)
        rescue => e
          Rollbar.log_error("[Rollbar] Rollbar.js could not be added because #{e} exception")
          result
        end
      end

      def enabled?
        !!config[:enabled]
      end

      def add_js?(env, status, headers)
        enabled? && status == 200 && !env[JS_IS_INJECTED_KEY] &&
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

        head_open_end = find_end_of_head_open(body)
        return nil unless head_open_end

        build_body_with_js(env, body, head_open_end)
      rescue => e
        Rollbar.log_error("[Rollbar] Rollbar.js could not be added because #{e} exception")
        nil
      end

      def build_response(env, app_result, response_string)
        return result unless response_string

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

      def find_end_of_head_open(body)
        head_open = body.index(/<head\W/)
        body.index('>', head_open) if head_open
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
        script_tag("var _rollbarConfig = #{config[:options].to_json};", env)
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
          !::SecureHeaders::Configuration.get.current_csp[:script_src].to_a.include?("'unsafe-inline'")
      end
    end
  end
end
