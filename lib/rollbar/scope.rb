module Rollbar
  class Scope
    attr_reader :loaded_data
    private :loaded_data

    attr_reader :raw

    def initialize(initial_data = nil)
      initial_data ||= {}

      @raw = initial_data
      @loaded_data = {}
    end

    def data
      raw.reduce({}) do |acc, (k, _)|
        acc[k] = send(k)

        acc
      end
    end

    # With this version of clone we ensure that the loaded_data is empty
    def clone
      self.class.new(raw.clone)
    end

    private

    def load_value(key)
      return loaded_data[key.to_s] if loaded_data.key?(key.to_s)

      value_in_data = find_value(key)

      if value_in_data.respond_to?(:call)
        value = value_in_data.call
      else
        value = value_in_data
      end

      loaded_data[key.to_s] = value

      value
    end

    def key_in_data?(key)
      return false unless raw

      raw.key?(key.to_sym) || raw.key(key.to_s)
    end

    def find_value(key)
      raw[key.to_sym] || raw[key.to_s]
    end

    def method_missing(method_sym, *args, &block)
      if key_in_data?(method_sym)
        load_value(method_sym)
      elsif raw.respond_to?(method_sym)
        raw.send(method_sym, *args, &block)
      else
        nil
      end
    end

    def respond_to?(_)
      true
    end
  end
end
