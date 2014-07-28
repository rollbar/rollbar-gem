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
            request_data = extract_request_data_from_rack(env)
            
            person_data = Proc.new do
              ActiveRecord::Base.connection_pool.with_connection do
                extract_person_data_from_controller(env)
              end
            end
            
            context = nil
            
            if request_data[:route]
              route = request_data[:route]

              # make sure route is a hash built by RequestDataExtractor
              if route.is_a?(Hash) and not route.empty?
                context = "#{route[:controller]}" + '#' + "#{route[:action]}"
              end
            end
            
            # Scope a new notifier with request data and a Proc for person data
            # for any reports that happen while a controller is handling a request
            Thread.current[:_rollbar_notifier] = Rollbar.scope({
              :request => request_data,
              :person => person_data,
              :context => context
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
