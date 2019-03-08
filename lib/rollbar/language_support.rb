module Rollbar
  module LanguageSupport
    module_function

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

    def can_scrub_url?
      !version?('1.8')
    end

    def ruby_18?
      version?('1.8')
    end

    def ruby_19?
      version?('1.9')
    end

    def version?(version)
      numbers = version.split('.')

      numbers == ::RUBY_VERSION.split('.')[0, numbers.size]
    end

    def timeout_exceptions
      return [] if ruby_18? || ruby_19?

      [Net::ReadTimeout, Net::OpenTimeout]
    end
  end
end
