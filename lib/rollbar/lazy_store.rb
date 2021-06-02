module Rollbar
  class LazyStore
    attr_reader :loaded_data, :raw
    private :loaded_data

    def initialize(initial_data)
      initial_data ||= {}

      @raw = initial_data
      @loaded_data = {}
    end

    def eql?(other)
      if other.is_a?(self.class)
        raw.eql?(other.raw)
      else
        raw.eql?(other)
      end
    end

    def ==(other)
      raw == if other.is_a?(self.class)
               other.raw
             else
               other
             end
    end

    # With this version of clone we ensure that the loaded_data is empty
    def clone
      self.class.new(raw.clone)
    end

    def [](key)
      load_value(key)
    end

    def []=(key, value)
      raw[key] = value

      loaded_data.delete(key)
    end

    def data
      raw.reduce({}) do |acc, (k, _)|
        acc[k] = self[k]

        acc
      end
    end

    private

    def load_value(key)
      return loaded_data[key] if loaded_data.key?(key)
      return unless raw.key?(key)

      value = find_value(key)
      loaded_data[key] = value

      value
    end

    def find_value(key)
      value = raw[key]
      value.respond_to?(:call) ? value.call : value
    end

    def method_missing(method_sym, *args, &block)
      return raw.send(method_sym, *args, &block) if raw.respond_to?(method_sym)

      super
    end

    def respond_to_missing?(method_sym, include_all)
      raw.respond_to?(method_sym, include_all)
    end
  end
end
