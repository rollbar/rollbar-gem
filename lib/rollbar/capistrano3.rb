# This is a tasks file to use with Capistrano 3

require 'net/http'
require 'rubygems'
require 'json'
require 'rollbar/deploy'
require 'rollbar/capistrano_tasks'

namespace :rollbar do
  # dry_run? wasn't introduced till Capistrano 3.5.0; use the old fetch(:sshkit_backed)
  set :dry_run, (proc { ::Capistrano::Configuration.env.fetch(:sshkit_backend) == ::SSHKit::Backend::Printer })

  desc 'Send deployment started notification to Rollbar.'
  task :deploy_started do
    on primary fetch(:rollbar_role) do
      ::Rollbar::CapistranoTasks.deploy_started(self, self, fetch(:dry_run))
    end
  end

  desc 'Send deployment succeeded notification to Rollbar.'
  task :deploy_succeeded do
    on primary fetch(:rollbar_role) do
      ::Rollbar::CapistranoTasks.deploy_succeeded(self, self, fetch(:dry_run))
    end
  end

  desc 'Send deployment failed notification to Rollbar.'
  task :deploy_failed do
    on primary fetch(:rollbar_role) do
      ::Rollbar::CapistranoTasks.deploy_failed(self, self, fetch(:dry_run))
    end
  end

  task :fail do
    raise StandardError
  end
end

namespace :deploy do
  after 'deploy:set_current_revision', 'rollbar:deploy_started'
  after 'deploy:finished', 'rollbar:deploy_succeeded'
  after 'deploy:failed', 'rollbar:deploy_failed'

  # Used for testing :deploy_failed task
  # after 'rollbar:deploy_started', 'rollbar:fail'
end

namespace :load do
  task :defaults do
    set :rollbar_user,      (proc { fetch :local_user, ENV['USER'] || ENV['USERNAME'] })
    set :rollbar_env,       (proc { fetch :rails_env, 'production' })
    set :rollbar_token,     (proc { abort "Please specify the Rollbar access token, set :rollbar_token, 'your token'" })
    set :rollbar_role,      (proc { :app })
    set :rollbar_revision,  (proc { fetch :current_revision })
  end
end
