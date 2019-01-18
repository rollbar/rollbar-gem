# This is a tasks file to use with Capistrano 2

require 'capistrano'
require 'rollbar/deploy'
require 'net/http'
require 'rubygems'
require 'json'
require 'rollbar/capistrano_tasks'

module Rollbar
  # Module for loading Rollbar Capistrano tasks into Capistrano 2
  module Capistrano
    def self.load_into(configuration)
      configuration.load do
        before 'deploy', 'rollbar:deploy_started'

        after 'deploy', 'rollbar:deploy_succeeded'
        after 'deploy:migrations', 'rollbar:deploy_succeeded'
        after 'deploy:cold',       'rollbar:deploy_succeeded'

        _cset(:rollbar_role)  { :app }
        _cset(:rollbar_user)  { ENV['USER'] || ENV['USERNAME'] }
        _cset(:rollbar_env)   { fetch(:rails_env, 'production') }
        _cset(:rollbar_token) { abort("Please specify the Rollbar access token, set :rollbar_token, 'your token'") }
        _cset(:rollbar_revision) { current_revision }
        _cset(:rollbar_comment) { nil }

        namespace :rollbar do
          desc 'Send deployment started notification to Rollbar.'
          task :deploy_started do
            ::Rollbar::CapistranoTasks.deploy_started(self, logger, configuration.method(:dry_run))
          end

          desc 'Send deployment succeeded notification to Rollbar.'
          task :deploy_succeeded do
            ::Rollbar::CapistranoTasks.deploy_succeeded(self, logger, configuration.method(:dry_run))
          end

          desc 'Send deployment failed notification to Rollbar.'
          task :deploy_failed do
            ::Rollbar::CapistranoTasks.deploy_failed(self, logger, configuration.method(:dry_run))
          end
        end
      end
    end
  end
end

Rollbar::Capistrano.load_into(Capistrano::Configuration.instance) if Capistrano::Configuration.instance
