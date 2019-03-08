module Rollbar
  module JSON
    module Oj
      module_function

      def options
        {
          :mode => :compat,
          :use_to_json => false,
          :symbol_keys => false,
          :circular => false
        }
      end
    end
  end
end
