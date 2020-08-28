module Rollbar
  module LanguageSupport
    module_function

    def const_defined?(mod, target, inherit = true)
      mod.const_defined?(target, inherit)
    end

    def const_get(mod, target, inherit = true)
      mod.const_get(target, inherit)
    end

    def version?(version)
      numbers = version.split('.')

      numbers == ::RUBY_VERSION.split('.')[0, numbers.size]
    end

    def timeout_exceptions
      [Net::ReadTimeout, Net::OpenTimeout]
    end
  end
end
