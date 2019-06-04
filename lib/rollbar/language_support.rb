module Rollbar
  module LanguageSupport
    module_function

    def const_defined?(mod, target, inherit = true)
      mod.const_defined?(target, inherit)
    end

    def const_get(mod, target, inherit = true)
      mod.const_get(target, inherit)
    end

    def ruby_19?
      version?('1.9')
    end

    def version?(version)
      numbers = version.split('.')

      numbers == ::RUBY_VERSION.split('.')[0, numbers.size]
    end

    def timeout_exceptions
      return [] if ruby_19?

      [Net::ReadTimeout, Net::OpenTimeout]
    end
  end
end
