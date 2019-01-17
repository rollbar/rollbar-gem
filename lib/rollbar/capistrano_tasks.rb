require 'capistrano'
require 'rollbar/deploy'

module Rollbar
    module CapistranoTasks
        
        def self.deploy_started(capistrano, dry_run_proc)
            
            capistrano.warn("You need to upgrade capistrano to '>= 3.1' version in order to correctly report deploys to Rollbar. (On 3.0, the reported revision will be incorrect.)") if Capistrano::VERSION =~ /^3\.0/

            capistrano.info "Notifying Rollbar of deployment start"
            
            result = ::Rollbar::Deploy.report(
                access_token: fetch(:rollbar_token),
                environment: fetch(:rollbar_env),
                revision: fetch(:rollbar_revision),
                rollbar_username: fetch(:rollbar_user),
                local_username: fetch(:rollbar_user),
                comment: fetch(:rollbar_comment),
                status: :started,
                proxy: :ENV,
                dry_run: dry_run_proc.call
            )
            
            capistrano.info result[:request_info]
            
            if dry_run_proc.call
            
                capistrano.set :rollbar_deploy_id, 123
                capistrano.info "Skipping sending HTTP requests to Rollbar in dry run."
            
            else
            
                capistrano.info result[:response_info] if result[:response_info]
            
                if result[:deploy_id]
                  capistrano.set :rollbar_deploy_id, result[:deploy_id]
                else
                  capistrano.error "Unable to report deploy to Rollbar"
                end
            
            end
            
        end
        
        def self.deploy_succeeded(capistrano, dry_run_proc)
            capistrano.warn("You need to upgrade capistrano to '>= 3.1' version in order to correctly report deploys to Rollbar. (On 3.0, the reported revision will be incorrect.)") if Capistrano::VERSION =~ /^3\.0/
            
            capistrano.info "Setting deployment status to `succeeded` in Rollbar"  
            
            deploy_id = fetch(:rollbar_deploy_id)
            
            if deploy_id      
                result = ::Rollbar::Deploy.update(
                  access_token: fetch(:rollbar_token),
                  deploy_id: deploy_id,
                  status: :succeeded,
                  proxy: :ENV,
                  dry_run: dry_run_proc.call
                )
                
                capistrano.info result[:request_info]
                
                capistrano.info result[:response_info] if result[:response_info]
                
                if dry_run_proc.call
                  
                  capistrano.info "Skipping sending HTTP requests to Rollbar in dry run."
                  
                else
                  
                  if result[:response].is_a? Net::HTTPSuccess
                    capistrano.info "Set deployment status to `succeeded` in Rollbar"  
                  else
                    capistrano.error "Unable to update deploy status in Rollbar"
                  end
                  
                end
            else
                capistrano.error "Failed to update the deploy in Rollbar. No deploy id available."
            end
        end
        
        def self.deploy_failed(capistrano, dry_run_proc)
            
            capistrano.warn("You need to upgrade capistrano to '>= 3.1' version in order to correctly report deploys to Rollbar. (On 3.0, the reported revision will be incorrect.)") if Capistrano::VERSION =~ /^3\.0/
      
            capistrano.info "Setting deployment status to `failed` in Rollbar"  
            
            deploy_id = fetch(:rollbar_deploy_id)
            
            if deploy_id      
                result = ::Rollbar::Deploy.update(
                  access_token: fetch(:rollbar_token),
                  deploy_id: deploy_id,
                  status: :failed,
                  proxy: :ENV,
                  dry_run: dry_run_proc.call
                )
                
                capistrano.info result[:request_info]
                
                capistrano.info result[:response_info] if result[:response_info]
            
                if dry_run_proc.call
                  
                  capistrano.info "Skipping sending HTTP requests to Rollbar in dry run."
                  
                else
                  
                  if result[:response].is_a? Net::HTTPSuccess
                    capistrano.info "Set deployment status to `failed` in Rollbar"  
                  else
                    capistrano.error "Unable to update deploy status in Rollbar"
                  end
                  
                end
            else
                capistrano.error "Failed to update the deploy in Rollbar. No deploy id available."
            end
            
        end
        
    end
end