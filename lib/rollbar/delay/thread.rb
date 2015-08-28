module Rollbar
  module Delay
    class Thread
      def self.call(payload)
        new.call(payload)
      end

      def call(payload)
        ::Thread.new do
          begin
            Rollbar.process_from_async_handler(payload)
          rescue
            # Here we swallow the exception:
            # 1. The original report wasn't sent.
            # 2. An internal error was sent and logged
            #
            # If users want to handle this in some way they
            # can provide a more custom Thread based implementation
          end
        end
      end
    end
  end
end
