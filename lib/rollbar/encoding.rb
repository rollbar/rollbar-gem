module Rollbar
  module Encoding
    class << self
      attr_accessor :encoding_class
    end

    def self.setup
      require 'rollbar/encoding/encoder'
      self.encoding_class = Rollbar::Encoding::Encoder
    end

    def self.encode(object)
      case object
      when Numeric, TrueClass, FalseClass, NilClass
        object
      else
        encoding_class.new(object).encode
      end
    end
  end
end

Rollbar::Encoding.setup
