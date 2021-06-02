require 'rollbar/scrubbers/params'
require 'rollbar/util'

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

        # Prepare objects to be handled by the payload serializer.
        #
        # Hashes and Arrays are traversed. Then all types execpt strings and
        # immediates are exported using #inspect. Sending the object itself to the
        # serializer can result in large recursive expansions, especially in Rails
        # environments with ActiveRecord, ActiveSupport, etc. on the stack.
        # Other export options could be #to_s, #to_h, and #as_json. Several of these
        # will omit the class name, or are not implemented for many types.
        #
        # #inspect has the advantage that it is specifically intended for debugging
        # output. If the user wants more or different information in the payload
        # about a specific type, #inspect is the correct place to implement it.
        # Likewise the default implementation should be oriented toward usefulness
        # in debugging.
        #
        # Because #inspect outputs a string, it can be handled well by the string
        # truncation strategy for large payloads.
        #
        def prepare_value(value)
          unless value.is_a?(Hash) || value.is_a?(Array)
            return simple_value?(value) ? value : value.inspect
          end

          cloned_value = ::Rollbar::Util.deep_copy(value)
          ::Rollbar::Util.iterate_and_update_with_block(cloned_value) do |v|
            simple_value?(v) ? v : v.inspect
          end

          cloned_value
        end

        def simple_classes
          if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.4.0')
            [String, Symbol, Integer, Float, TrueClass, FalseClass, NilClass]
          else
            [String, Symbol, Fixnum, Bignum, Float, TrueClass, FalseClass, NilClass] # rubocop:disable Lint/UnifiedInteger
          end
        end

        def simple_value?(value)
          simple_classes.each do |klass|
            # Use instance_of? so that subclasses and module containers will
            # be treated like complex object types, not simple values.
            return true if value.instance_of?(klass)
          end

          false
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
