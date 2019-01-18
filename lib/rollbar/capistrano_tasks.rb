require 'capistrano'
require 'capistrano/version'
require 'rollbar/deploy'

module Rollbar
  # Module containing the logic of Capistrano tasks for deploy tracking
  module CapistranoTasks
    def self.deploy_started(capistrano, logger, dry_run_proc)
      logger.warn("You need to upgrade capistrano to '>= 3.1' version in order to correctly report deploys to Rollbar. (On 3.0, the reported revision will be incorrect.)") if ::Capistrano::VERSION =~ /^3\.0/

      logger.info 'Notifying Rollbar of deployment start'

      result = ::Rollbar::Deploy.report(
        :access_token => capistrano.fetch(:rollbar_token),
        :environment => capistrano.fetch(:rollbar_env),
        :revision => capistrano.fetch(:rollbar_revision),
        :rollbar_username => capistrano.fetch(:rollbar_user),
        :local_username => capistrano.fetch(:rollbar_user),
        :comment => capistrano.fetch(:rollbar_comment),
        :status => :started,
        :proxy => :ENV,
        :dry_run => dry_run_proc.call
      )

      logger.info result[:request_info]

      if dry_run_proc.call

        capistrano.set :rollbar_deploy_id, 123
        logger.info 'Skipping sending HTTP requests to Rollbar in dry run.'

      else

        logger.info result[:response_info] if result[:response_info]

        if result[:deploy_id]
          capistrano.set :rollbar_deploy_id, result[:deploy_id]
        else
          logger.error 'Unable to report deploy to Rollbar'
        end

      end
    end

    def self.deploy_succeeded(capistrano, logger, dry_run_proc)
      logger.warn("You need to upgrade capistrano to '>= 3.1' version in order to correctly report deploys to Rollbar. (On 3.0, the reported revision will be incorrect.)") if ::Capistrano::VERSION =~ /^3\.0/

      logger.info 'Setting deployment status to `succeeded` in Rollbar'

      deploy_id = capistrano.fetch(:rollbar_deploy_id)

      if deploy_id
        result = ::Rollbar::Deploy.update(
          :access_token => capistrano.fetch(:rollbar_token),
          :deploy_id => deploy_id,
          :status => :succeeded,
          :proxy => :ENV,
          :dry_run => dry_run_proc.call
        )

        logger.info result[:request_info]

        logger.info result[:response_info] if result[:response_info]

        if dry_run_proc.call

          logger.info 'Skipping sending HTTP requests to Rollbar in dry run.'

        else

          if result[:response].is_a? Net::HTTPSuccess
            logger.info 'Set deployment status to `succeeded` in Rollbar'
          else
            logger.error 'Unable to update deploy status in Rollbar'
          end

        end
      else
        logger.error 'Failed to update the deploy in Rollbar. No deploy id available.'
      end
    end

    def self.deploy_failed(capistrano, logger, dry_run_proc)
      logger.warn("You need to upgrade capistrano to '>= 3.1' version in order to correctly report deploys to Rollbar. (On 3.0, the reported revision will be incorrect.)") if ::Capistrano::VERSION =~ /^3\.0/

      logger.info 'Setting deployment status to `failed` in Rollbar'

      deploy_id = capistrano.fetch(:rollbar_deploy_id)

      if deploy_id
        result = ::Rollbar::Deploy.update(
          :access_token => capistrano.fetch(:rollbar_token),
          :deploy_id => deploy_id,
          :status => :failed,
          :proxy => :ENV,
          :dry_run => dry_run_proc.call
        )

        logger.info result[:request_info]

        logger.info result[:response_info] if result[:response_info]

        if dry_run_proc.call

          logger.info 'Skipping sending HTTP requests to Rollbar in dry run.'

        else

          if result[:response].is_a? Net::HTTPSuccess
            logger.info 'Set deployment status to `failed` in Rollbar'
          else
            logger.error 'Unable to update deploy status in Rollbar'
          end

        end
      else
        logger.error 'Failed to update the deploy in Rollbar. No deploy id available.'
      end
    end
  end
end
