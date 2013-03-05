require 'better_errors'

module BetterErrors
  class Middleware
    alias_method :orig_show_error_page, :show_error_page
    
    private

    def show_error_page(env)
      exception = @error_page.exception
      
      exception_data = nil
      begin
        controller = env['action_controller.instance']
        request_data = controller.try(:rollbar_request_data)
        person_data = controller.try(:rollbar_person_data)
        exception_data = Rollbar.report_exception(exception, request_data, person_data)
      rescue => e
        # TODO use logger here?
        puts "[Rollbar] Exception while reporting exception to Rollbar: #{e}" 
      end
      
      # if an exception was reported, save uuid in the env
      # so it can be displayed to the user on the error page
      if exception_data
        begin
          env['rollbar.exception_uuid'] = exception_data[:uuid]
        rescue => e
          puts "[Rollbar] Exception saving uuid in env: #{e}"
        end
      end
      
      # now continue as normal
      orig_show_error_page(env)
    end
  end
end
