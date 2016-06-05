require 'oj'

module Rollbar
  module JSON
    module Oj
      OPTIONS = {
        :mode => :compat,
        :use_to_json => false,
        :symbol_keys => false,
        :circular => false
      }.freeze

      def dump(object)
        ::Oj.dump(object, OPTIONS)
      end

      def load(string)
        ::Oj.load(string, OPTIONS)
      end
    end
  end
end
