module Ratchetio
  module Rails
    module RequestDataExtractor
      ATTACHMENT_CLASSES = [
        ActionDispatch::Http::UploadedFile,
        Rack::Multipart::UploadedFile
      ].freeze

      def extract_person_data_from_controller(env)
        controller = env['action_controller.instance']
        person_data = controller ? controller.try(:ratchetio_person_data) : {}
      end

      def extract_request_data_from_rack(env)
        route = ::Rails.application.routes.recognize_path(env['PATH_INFO']) rescue {}
        sensitive_params = sensitive_params_list(env)
        request_params = {
          :controller => route[:controller],
          :action => route[:action],
          :format => route[:format],
        }
        get_params = ActiveSupport::HashWithIndifferentAccess.new(Rack::Utils.parse_nested_query(env['QUERY_STRING']))
        get_params = ratchetio_filtered_params(sensitive_params, get_params)
        post_params = ratchetio_filtered_params(sensitive_params, env['rack.request.form_hash'] || {})

        headers = env.keys.grep(/^HTTP_/).map do |header|
          name = header.gsub(/^HTTP_/, '').split('_').map(&:capitalize).join('-')
          { name => env[header] }
        end.inject(:merge)

        {
          :params => get_params.merge(post_params).merge(request_params),
          :url => [env['rack.url_scheme'], '://', env['HTTP_HOST'], env['ORIGINAL_FULLPATH']].join,
          :user_ip => env['HTTP_X_REAL_IP'] || env['HTTP_X_FORWARDED_FOR'] || env['REMOTE_ADDR'],
          :headers => headers,
          :GET => get_params,
          :POST => post_params,
          :session => env['rack.session.options'],
          :method => env['REQUEST_METHOD']
        }
      end

      private

      def ratchetio_filtered_params(sensitive_params, params)
        params.inject({}) do |result, (key, value)|
          if key.to_sym.in?(sensitive_params)
            result[key] = '*' * (value.length rescue 8)
          elsif value.is_a?(Hash)
            result[key] = ratchetio_filtered_params(sensitive_params, value)
          elsif value.class.in?(ATTACHMENT_CLASSES)
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
        Ratchetio.configuration.scrub_fields |= Array.new(env['action_dispatch.parameter_filter'])
      end
    end
  end
end
