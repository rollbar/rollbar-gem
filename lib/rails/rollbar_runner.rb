require 'rails'
require 'rollbar'

APP_PATH = File.expand_path('config/application', Dir.pwd)

module Rails
  class RollbarRunner
    class GemResolver
      def railties_gem
        Gem::Specification.find_by_name('railties')
      end
    end

    class LegacyGemResolver
      def railties_gem
        searcher = Gem::GemPathSearcher.new
        searcher.find('rails')
      end
    end

    attr_reader :command

    def initialize
      @command = ARGV[0]
    end

    def run
      prepare_environment

      rollbar_managed { eval_runner }
    end

    def prepare_environment
      require File.expand_path('../environment', APP_PATH)
      ::Rails.application.require_environment!
    end

    def eval_runner
      string_to_eval = File.read(runner_path)

      ::Rails.module_eval(<<-EOL, __FILE__, __LINE__ + 2)
          #{string_to_eval}
      EOL
    end

    def rollbar_managed
      yield
    rescue => e
      Rollbar.scope(:custom => { :command => command }).error(e)
      raise
    end

    def runner_path
      railties_gem_dir + '/lib/rails/commands/runner.rb'
    end

    def railties_gem
      resolver_class = Gem::Specification.respond_to?(:find_by_name) ? GemResolver : LegacyGemResolver
      gem = resolver_class.new.railties_gem

      abort 'railties gem not found' unless gem

      gem
    end

    def railties_gem_dir
      railties_gem.gem_dir
    end
  end
end
