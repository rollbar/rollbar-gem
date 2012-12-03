module Goalie
  class CustomErrorPages
    alias_method :orig_render_exception, :render_exception
    
    private

    def render_exception(env, exception)
      begin
        controller = env['action_controller.instance']
        request_data = controller.try(:ratchetio_request_data)
        person_data = controller.try(:ratchetio_person_data)
        Ratchetio.report_exception(exception, request_data, person_data)
      rescue => e
        # TODO use logger here?
        puts "[Ratchet.io] Exception while reporting exception to Ratchet.io: #{e}" 
      end

      # now continue as normal
      orig_render_exception(env, exception)
    end
  end
end

