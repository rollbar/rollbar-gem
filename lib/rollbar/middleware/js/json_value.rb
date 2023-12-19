# Allows a Ruby String to be used to pass native Javascript objects/functions
# when calling JSON#generate with a Rollbar::JSON::JsOptionsState instance.
#
# Example:
# JSON.generate(
#   { foo: Rollbar::JSON::Value.new('function(){ alert("bar") }') },
#   Rollbar::JSON::JsOptionsState.new
# )
#
# => '{"foo":function(){ alert(\"bar\") }}'
#
# MUST use the Ruby JSON encoder, as in the example. The ActiveSupport encoder,
# which is installed with Rails, is invoked when calling Hash#to_json and #as_json,
# and will not work.
#
module Rollbar
  module JSON
    class JsOptionsState < ::JSON::State; end

    class Value # :nodoc:
      attr_accessor :value

      def initialize(value)
        @value = value
      end

      def to_json(opts = {})
        # Return the raw value if this is from the js middleware
        return value if opts.class == Rollbar::JSON::JsOptionsState

        # Otherwise convert to a string
        %Q["#{value}"]
      end
    end
  end
end
