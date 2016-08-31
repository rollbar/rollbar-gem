Rollbar.plugins.define('rake') do
  require_dependency('rake')
  dependency { !configuration.disable_monkey_patch }
  dependency { defined?(Rake) }

  module Rollbar
    module Rake
      def self.patch!
        skip_patch && return unless patch?

        ::Rake::Application.class_eval do
          alias_method :orig_display_error_message, :display_error_message

          def display_error_message(ex)
            Rollbar.error(ex, :use_exception_level_filters => true)
            orig_display_error_message(ex)
          end
        end
      end

      def self.skip_patch
        warn('[Rollbar] Rollbar is disabled for Rake tasks since your Rake version is under 0.9.x. Please upgrade to 0.9.x or higher.')
      end

      def self.patch?
        return false unless rake_version

        major, minor, = rake_version.split('.').map(&:to_i)

        major > 0 || major == 0 && minor > 8
      end

      def self.rake_version
        if Object.const_defined?('RAKEVERSION')
          return RAKEVERSION
        elsif ::Rake.const_defined?('VERSION')
          return ::Rake::VERSION
        end
      end
    end
  end

  execute do
    Rollbar::Rake.patch!
  end
end
