module Rollbar
  class Notifier
    class TraceWithBindings # :nodoc:
      attr_reader :frames, :exception_frames

      def initialize
        reset
      end

      def reset
        @frames = []
        @exception_frames = []
        @exception_signature = nil
      end

      def enable
        reset
        trace_point.enable if defined?(TracePoint)
      end

      def disable
        trace_point.disable if defined?(TracePoint)
      end

      def exception_signature(trace)
        # use the exception backtrace to detect reraised exception.
        trace.raised_exception.backtrace.first
      end

      def detect_reraise(trace)
        @exception_signature == exception_signature(trace)
      end

      def trace_point
        return unless defined?(TracePoint)

        @trace_point ||= TracePoint.new(:call, :return, :b_call, :b_return, :c_call, :c_return, :raise) do |tp|
          case tp.event
          when :call, :b_call, :c_call, :class
            frames.push frame(tp)
          when :return, :b_return, :c_return, :end
            frames.pop
          when :raise
            unless detect_reraise(tp) # ignore reraised exceptions
              @exception_frames = @frames.dup # may be possible to optimize better than #dup
              @exception_signature = exception_signature(tp)
            end
          end
        end
      end

      def frame(trace)
        {
          :binding => trace.binding,
          :defined_class => trace.defined_class,
          :method_id => trace.method_id,
          :path => trace.path,
          :lineno => trace.lineno
        }
      end
    end
  end
end
