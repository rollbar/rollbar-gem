require 'rack'
require 'rack/response'

module Rollbar
  module Middleware
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

        _call(env, result)
      end

      private

      def _call(env, result)
        return result unless should_add_js?(env, result[0], result[1])

        if response_string = add_js(env, result[2])
          env[JS_IS_INJECTED_KEY] = true
          response = ::Rack::Response.new(response_string, result[0], result[1])

          response.finish
        else
          result
        end
      rescue => e
        Rollbar.log_error("[Rollbar] Rollbar.js could not be added because #{e} exception")
        result
      end

      def enabled?
        !!config[:enabled]
      end

      def should_add_js?(env, status, headers)
        enabled? &&
          status == 200 &&
          !env[JS_IS_INJECTED_KEY] &&
          html?(headers) &&
          !attachment?(headers) &&
          !streaming?(env)
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

        if head_open_end
          body = body[0..head_open_end] <<
                 config_js_tag(env) <<
                 snippet_js_tag(env) <<
                 body[head_open_end + 1..-1]
        end

        body
      rescue => e
        Rollbar.log_error("[Rollbar] Rollbar.js could not be added because #{e} exception")
        nil
      end

      def find_end_of_head_open(body)
        head_open = body.index(/<head\W/)
        body.index('>', head_open) if head_open
      end

      def join_body(response)
        source = nil
        response.each { |fragment| source ? (source << fragment.to_s) : (source = fragment.to_s)}
        source
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
        nonce = script_nonce(env)
        nonce_attr = " nonce=\"#{nonce}\"" if nonce
        script_tag_content = "\n<script type=\"text/javascript\"#{nonce_attr}>#{content}</script>"

        html_safe_if_needed(script_tag_content)
      end

      def script_nonce(env)
        return if !!config[:without_script_nonce]
        if defined?(::SecureHeaders) && ::SecureHeaders.respond_to?(:content_security_policy_script_nonce)
          ::SecureHeaders.content_security_policy_script_nonce(::Rack::Request.new(env))
        end
      end

      def html_safe_if_needed(string)
        string = string.html_safe if string.respond_to?(:html_safe)
        string
      end
    end
  end
end
