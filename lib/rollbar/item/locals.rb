require 'rollbar/notifier'
require 'rollbar/scrubbers/params'

module Rollbar
  class Item
    class Locals # :nodoc:
      class << self
        def exception_frames
          Rollbar.notifier.exception_bindings
        end

        def locals_for_location(filename, lineno)
          if (frame = frame_for_location(filename, lineno))
            scrub(locals_for(frame[:binding]))
          else
            {}
          end
        end

        def frame_for_location(filename, lineno)
          while (frame = exception_frames.pop)
            return nil unless frame
            return frame if matching_frame?(frame, filename, lineno)
          end
          nil
        end

        private

        def matching_frame?(frame, filename, lineno)
          frame[:path] == filename && frame[:lineno].to_i <= lineno.to_i
        end

        def locals_for(frame)
          {}.tap do |hash|
            frame.local_variables.map do |var|
              hash[var] = prepare_value(frame.local_variable_get(var))
            end
          end
        end

        def prepare_value(value)
          value.to_s
        end

        def scrub(hash)
          Rollbar::Scrubbers::Params.call(
            :params => hash,
            :config => Rollbar.configuration.scrub_fields,
            :whitelist => Rollbar.configuration.scrub_whitelist
          )
        end
      end
    end
  end
end
