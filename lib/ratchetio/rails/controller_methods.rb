module Ratchetio
  module Rails
    module ControllerMethods
    
      def ratchetio_request_data
        { :controller => params[:controller],
          :action => params[:action] }
      end

    end
  end
end
