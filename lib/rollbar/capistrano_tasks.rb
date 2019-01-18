require 'capistrano'
require 'capistrano/version'
require 'rollbar/deploy'

module Rollbar
  # Module containing the logic of Capistrano tasks for deploy tracking
  module CapistranoTasks
    class << self
      def deploy_started(capistrano, logger, dry_run)
        deploy_task(logger, {desc: 'Notifying Rollbar of deployment start'}) do
          result = report_deploy_started(capistrano, dry_run)

          info_request_response(logger, result)
  
          capistrano.set(:rollbar_deploy_id, 123) if dry_run
  
          skip_in_dry_run(logger, dry_run) do
            if (deploy_id = result[:data][:deploy_id])
              capistrano.set :rollbar_deploy_id, deploy_id
            else
              logger.error 'Unable to report deploy to Rollbar'
            end
          end
        end
      end

      def deploy_succeeded(capistrano, logger, dry_run)
        deploy_update(capistrano, logger, dry_run, :desc => 'Setting deployment status to `succeeded` in Rollbar') do
          report_deploy_succeeded(capistrano, dry_run)
        end
      end

      def deploy_failed(capistrano, logger, dry_run)
        deploy_update(capistrano, logger, dry_run, :desc => 'Setting deployment status to `failed` in Rollbar') do
          report_deploy_failed(capistrano, dry_run)
        end
      end

      private
      
      def deploy_task(logger, opts = {})
        capistrano_300_warning(logger)
        logger.info opts[:desc] if opts[:desc]
        yield
      end

      def deploy_update(capistrano, logger, dry_run, opts = {})
        deploy_task(logger, opts) do
          depend_on_deploy_id(capistrano, logger) do
            result = yield
  
            info_request_response(logger, result)
  
            skip_in_dry_run(logger, dry_run) do
              if result[:response].is_a?(Net::HTTPSuccess)
                logger.info 'Set deployment status to `failed` in Rollbar'
              else
                logger.error 'Unable to update deploy status in Rollbar'
              end
            end
          end
        end
      end

      def capistrano_300_warning(logger)
        logger.warn("You need to upgrade capistrano to '>= 3.1' version in order to correctly report deploys to Rollbar. (On 3.0, the reported revision will be incorrect.)") if ::Capistrano::VERSION =~ /^3\.0/
      end

      def report_deploy_started(capistrano, dry_run)
        ::Rollbar::Deploy.report(
          {
            :rollbar_username => capistrano.fetch(:rollbar_user),
            :local_username => capistrano.fetch(:rollbar_user),
            :comment => capistrano.fetch(:rollbar_comment),
            :status => :started,
            :proxy => :ENV,
            :dry_run => dry_run
          },
          :access_token => capistrano.fetch(:rollbar_token),
          :environment => capistrano.fetch(:rollbar_env),
          :revision => capistrano.fetch(:rollbar_revision)
        )
      end

      def report_deploy_succeeded(capistrano, dry_run)
        ::Rollbar::Deploy.update(
          {
            :proxy => :ENV,
            :dry_run => dry_run
          },
          :access_token => capistrano.fetch(:rollbar_token),
          :deploy_id => capistrano.fetch(:rollbar_deploy_id),
          :status => :succeeded
        )
      end

      def report_deploy_failed(capistrano, dry_run)
        ::Rollbar::Deploy.update(
          {
            :proxy => :ENV,
            :dry_run => dry_run
          },
          :access_token => capistrano.fetch(:rollbar_token),
          :deploy_id => capistrano.fetch(:rollbar_deploy_id),
          :status => :failed
        )
      end

      def depend_on_deploy_id(capistrano, logger)
        if capistrano.fetch(:rollbar_deploy_id)
          yield
        else
          logger.error 'Failed to update the deploy in Rollbar. No deploy id available.'
        end
      end

      def skip_in_dry_run(logger, dry_run)
        if dry_run
          logger.info 'Skipping sending HTTP requests to Rollbar in dry run.'
        else
          yield
        end
      end

      def info_request_response(logger, result)
        logger.info result[:request_info]
        logger.info result[:response_info] if result[:response_info]
      end
    end
  end
end
