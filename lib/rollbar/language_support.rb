module Rollbar
  module LanguageSupport
    extend self

    def const_defined?(mod, target, inherit = true)
      if ruby_18?
        mod.const_defined?(target)
      else
        mod.const_defined?(target, inherit)
      end
    end

    def const_get(mod, target, inherit = true)
      if ruby_18?
        mod.const_get(target)
      else
        mod.const_get(target, inherit)
      end
    end

    def ruby_18?
      version?('1.8')
    end

    def version?(version)
      numbers = version.split('.')

      numbers == ::RUBY_VERSION.split('.')[0, numbers.size]
    end
  end
end
