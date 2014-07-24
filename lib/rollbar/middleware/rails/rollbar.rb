module Rollbar
  module Middleware
    module Rails
      class RollbarMiddleware
        include RequestDataExtractor
        include ExceptionReporter
        
        def initialize(app)
          @app = app
        end
        
        def call(env)
          begin
            # Scope a new notifier with request data and a Proc for person data
            # for any reports that happen while a controller is handling a request
            Thread.current[:_rollbar_notifier] = Rollbar.scope({
              :request => extract_request_data_from_rack(env),
              :person => Proc.new { extract_person_data_from_controller(env) }
            })
            
            response = @app.call(env)
          rescue Exception => exception
            report_exception_to_rollbar(env, exception)
            
            Thread.current[:_rollbar_notifier] = nil
            
            raise
          end
          
          if env["rack.exception"]
            report_exception_to_rollbar(env, env["rack.exception"])
          end
          
          Thread.current[:_rollbar_notifier] = nil
          
          response
        end
      end
    end
  end
end
