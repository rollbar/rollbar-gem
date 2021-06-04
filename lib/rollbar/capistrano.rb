# This is a tasks file to use with Capistrano 2

require 'capistrano'
require 'rollbar/deploy'
require 'net/http'
require 'rubygems'
require 'json'
require 'rollbar/capistrano_tasks'

module Rollbar
  # Module for loading Rollbar Capistrano tasks into Capistrano 2
  module Capistrano2
    class << self
      def load_into(configuration)
        load_tasks(configuration)
        load_tasks_flow(configuration)
        load_properties(configuration)
      end

      private

      def load_tasks_flow(configuration)
        configuration.load do
          before 'deploy', 'rollbar:deploy_started'

          after 'deploy', 'rollbar:deploy_succeeded'
          after 'deploy:migrations', 'rollbar:deploy_succeeded'
          after 'deploy:cold',       'rollbar:deploy_succeeded'
        end
      end

      def load_properties(configuration)
        configuration.load do
          _cset(:rollbar_role)  { :app }
          _cset(:rollbar_user)  { ENV['USER'] || ENV['USERNAME'] }
          _cset(:rollbar_env)   { fetch(:rails_env, 'production') }
          _cset(:rollbar_token) do
            abort(
              "Please specify the Rollbar access token, set :rollbar_token, 'your token'"
            )
          end
          _cset(:rollbar_revision) { real_revision }
          _cset(:rollbar_comment) { nil }
        end
      end

      def load_tasks(configuration)
        load_deploy_started(configuration)
        load_deploy_succeeded(configuration)
      end

      def load_deploy_started(configuration)
        load_task(
          :desc => 'Send deployment started notification to Rollbar.',
          :task => :deploy_started,
          :configuration => configuration
        ) do
          ::Rollbar::CapistranoTasks.deploy_started(
            configuration, configuration.logger, configuration.dry_run
          )
        end
      end

      def load_deploy_succeeded(configuration)
        load_task(
          :desc => 'Send deployment succeeded notification to Rollbar.',
          :task => :deploy_succeeded,
          :configuration => configuration
        ) do
          ::Rollbar::CapistranoTasks.deploy_succeeded(
            configuration, configuration.logger, configuration.dry_run
          )
        end
      end

      def load_task(configuration:, desc:, task:, &block)
        configuration.load do
          namespace :rollbar do
            desc(desc)
            task(task, &block)
          end
        end
      end
    end
  end
end

if Capistrano::Configuration.instance
  Rollbar::Capistrano2.load_into(Capistrano::Configuration.instance)
end
