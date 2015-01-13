module Goalie
  class CustomErrorPages
    alias_method :orig_render_exception, :render_exception

    private

    def render_exception(env, exception)
      exception_data = nil
      begin
        controller = env['action_controller.instance']
        request_data = controller.rollbar_request_data rescue nil
        person_data = controller.rollbar_person_data rescue nil
        exception_data = Rollbar.scope(:request => request_data, :person => person_data).error(exception, :use_exception_level_filters => true)
      rescue => e
        Rollbar.log_warning "[Rollbar] Exception while reporting exception to Rollbar: #{e}"
      end

      # if an exception was reported, save uuid in the env
      # so it can be displayed to the user on the error page
      if exception_data.is_a?(Hash)
        env['rollbar.exception_uuid'] = exception_data[:uuid]
        Rollbar.log_info "[Rollbar] Exception uuid saved in env: #{exception_data[:uuid]}"
      elsif exception_data == 'disabled'
        Rollbar.log_info "[Rollbar] Exception not reported because Rollbar is disabled"
      elsif exception_data == 'ignored'
        Rollbar.log_info "[Rollbar] Exception not reported because it was ignored"
      end

      # now continue as normal
      orig_render_exception(env, exception)
    end
  end
end
