require 'rails'
require 'rollbar'

# Rails.root is not present here.
# RSpec needs ENV['DUMMYAPP_PATH'] in order to have a valid path.
# Dir.pwd is used in normal operation.
APP_PATH = File.expand_path(
  'config/application',
  (ENV['DUMMYAPP_PATH'] || Dir.pwd)
)

module Rails
  class RollbarRunner
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
      if Gem::Version.new(Rails.version) >= Gem::Version.new('5.1.0')
        rails5_runner
      else
        legacy_runner
      end
    end

    def legacy_runner
      string_to_eval = File.read(runner_path)

      ::Rails.module_eval(<<-FILE, __FILE__, __LINE__ + 1)
          #{string_to_eval}
      FILE
    end

    def rails5_runner
      require 'rails/command'

      Rails::Command.invoke 'runner', ARGV
    end

    def rollbar_managed
      yield
    rescue StandardError => e
      Rollbar.scope(:custom => { :command => command }).error(e)
      raise
    end

    def runner_path
      "#{railties_gem_dir}/lib/rails/commands/runner.rb"
    end

    def railties_gem
      gem = Gem::Specification.find_by_name('railties')

      abort 'railties gem not found' unless gem

      gem
    end

    def railties_gem_dir
      railties_gem.gem_dir
    end
  end
end
