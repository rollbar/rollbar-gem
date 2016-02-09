require "rollbar/js/version"

module Rollbar
  module Js
    extend self

    attr_reader :framework
    attr_reader :framework_loader

    def prepare
      @framework ||= detect_framework
      @framework_loader ||= load_framework_class.new

      @framework_loader.prepare
    end

    private

    def detect_framework
      case
      when defined?(::Rails::VERSION)
        :rails
      end
    end

    def load_framework_class
      require "rollbar/js/frameworks/#{framework}"

      Rollbar::Js::Frameworks.const_get(framework.to_s.capitalize)
    end
  end
end
