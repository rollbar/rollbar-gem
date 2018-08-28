Rollbar.plugins.define('rake') do
  require_dependency('rake')
  dependency { !configuration.disable_monkey_patch }
  dependency { defined?(Rake) }

  module Rollbar
    module Rake
      class << self
        attr_accessor :patched
      end

      module Handler
        def self.included(base)
          base.class_eval do
            alias_method :orig_display_error_message, :display_error_message
            alias_method :display_error_message, :display_error_message_with_rollbar
          end
        end

        def display_error_message_with_rollbar(ex)
          Rollbar.error(ex, :use_exception_level_filters => true)
          orig_display_error_message(ex)
        end
      end

      def self.patch!
        unless patch?
          skip_patch

          return
        end

        ::Rake.application.instance_eval do
          class << self
            include ::Rollbar::Rake::Handler
          end
        end

        self.patched = true
      end

      def self.skip_patch
        warn('[Rollbar] Rollbar is disabled for Rake tasks since your Rake version is under 0.9.x. Please upgrade to 0.9.x or higher.')
      end

      def self.patch?
        return false if patched?
        return false unless rake_version

        major, minor, = rake_version.split('.').map(&:to_i)

        major > 0 || major == 0 && minor > 8
      end

      def self.patched?
        patched
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
