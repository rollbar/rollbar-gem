require 'better_errors'

module BetterErrors
  class Middleware
    alias_method :orig_show_error_page, :show_error_page

    private

    def show_error_page(*args)
      exception = @error_page.exception

      env = args.first
      exception_data = nil
      begin
        controller = env['action_controller.instance']
        request_data = controller ? controller.rollbar_request_data : nil
        person_data = controller ? controller.rollbar_person_data : nil
        exception_data = Rollbar.report_exception(exception, request_data, person_data)
      rescue => e
        # TODO use logger here?
        puts "[Rollbar] Exception while reporting exception to Rollbar: #{e}"
      end

      # if an exception was reported, save uuid in the env
      # so it can be displayed to the user on the error page
      if exception_data.is_a?(Hash)
        env['rollbar.exception_uuid'] = exception_data[:uuid]
        puts "[Rollbar] Exception uuid saved in env: #{exception_data[:uuid]}"
      elsif exception_data == 'disabled'
        puts "[Rollbar] Exception not reported because Rollbar is disabled"
      elsif exception_data == 'ignored'
        puts "[Rollbar] Exception not reported because it was ignored"
      end

      # now continue as normal
      orig_show_error_page(*args)
    end
  end
end
