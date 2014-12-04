require 'rollbar/exception_reporter'
require 'rollbar/request_data_extractor'

module Rollbar
  module Middleware
    module Rack
      module Builder
        include ExceptionReporter
        include RequestDataExtractor

        def call_with_rollbar(env)
          Rollbar.reset_notifier!

          Rollbar.scoped(fetch_scope(env)) do
            begin
              call_without_rollbar(env)
            rescue ::Exception => exception
              report_exception_to_rollbar(env, exception)
              raise
            end
          end
        end

        def fetch_scope(env)
          request_data = extract_request_data_from_rack(env)
          {
            :request => request_data,
            :person => extract_person_data_from_controller(env)
          }
        rescue Exception => e
          report_exception_to_rollbar(env, e)
          raise
        end

        def self.included(base)
          base.send(:alias_method, :call_without_rollbar, :call)
          base.send(:alias_method, :call, :call_with_rollbar)
        end
      end
    end
  end
end
