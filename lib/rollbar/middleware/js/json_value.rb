# Allows a Ruby String to be used to create native Javascript objects
# when calling JSON#generate.
#
# Example:
# JSON.generate({ foo: Rollbar::JSON::Value.new('function(){ alert("bar") }') })
# => '{"foo":function(){ alert(\"bar\") }}'
#
# MUST use the Ruby JSON encoder, as in the example. The ActiveSupport encoder,
# which is installed with Rails, is invoked when calling Hash#to_json and #as_json,
# and will not work.
#
module Rollbar
  module JSON
    class Value # :nodoc:
      attr_accessor :value

      def initialize(value)
        @value = value
      end

      def to_json(*_args)
        value
      end
    end
  end
end
