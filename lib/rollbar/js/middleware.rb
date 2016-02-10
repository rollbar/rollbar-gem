require 'rack'
require 'rack/response'


module Rollbar
  module Js
    class Middleware
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

        status = result[0]
        headers = result[1]
        response = result[2]

        return result unless should_add_js?(env, status, headers)

        if response_string = add_js(response)
          env[JS_IS_INJECTED_KEY] = true
          response = ::Rack::Response.new(response_string, result[0], result[1])

          response.finish
        else
          result
        end
      end

      private

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

      def add_js(response)
        body = join_body(response)
        close_old_response(response)

        return nil unless body

        head_open_end = find_end_of_head_open(body)
        return nil unless head_open_end

        if head_open_end
          body = body[0..head_open_end] <<
                 config_js_tag <<
                 snippet_js_tag <<
                 body[head_open_end..-1]
        end

        body
      rescue => e
        Rollbar.log_error("[Rollbar] Rollbar.js could not be added because #{e} exception")
        nil
      end

      def find_end_of_head_open(body)
        head_open = body.index('<head')
        body.index('>', head_open) + 1 if head_open
      end

      def join_body(response)
        source = nil
        response.each { |fragment| source ? (source << fragment.to_s) : (source = fragment.to_s)}
        source
      end

      def close_old_response(response)
        response.close if response.respond_to?(:close)
      end

      def config_js_tag
        script_tag("var _rollbarConfig = #{config[:options].to_json};")
      end

      def snippet_js_tag
        script_tag(js_snippet)
      end

      def js_snippet
        SNIPPET
      end

      def script_tag(content)
        html_safe_if_needed("\n<script type=\"text/javascript\">#{content}</script>")
      end

      def html_safe_if_needed(string)
        string = string.html_safe if string.respond_to?(:html_safe)
        string
      end
    end
  end
end
