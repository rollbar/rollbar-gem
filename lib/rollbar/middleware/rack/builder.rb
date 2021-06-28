require 'rollbar/exception_reporter'
require 'rollbar/request_data_extractor'

module Rollbar
  module Middleware
    class Rack
      module Builder
        include ExceptionReporter
        include RequestDataExtractor

        def call_with_rollbar(env)
          Rollbar.reset_notifier!

          Rollbar.scoped(fetch_scope(env)) do
            begin
              call_without_rollbar(env)
            rescue ::Exception => e # rubocop:disable Lint/RescueException
              report_exception_to_rollbar(env, e)
              raise
            end
          end
        end

        def fetch_scope(env)
          {
            :request => proc { extract_request_data_from_rack(env) },
            :person => person_data_proc(env)
          }
        rescue Exception => e # rubocop:disable Lint/RescueException
          report_exception_to_rollbar(env, e)
          raise
        end

        def person_data_proc(env)
          proc { extract_person_data_from_controller(env) }
        end

        def self.included(base)
          base.send(:alias_method, :call_without_rollbar, :call)
          base.send(:alias_method, :call, :call_with_rollbar)
        end
      end
    end
  end
end
