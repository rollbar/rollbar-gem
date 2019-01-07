require 'capistrano'

module Rollbar
  module Deploy
    
    ENDPOINT = 'https://api.rollbar.com/api/1/deploy/'
      
    def self.report(
      access_token:,
      environment:,
      revision:,
      rollbar_username: nil,
      local_username: nil,
      comment: nil,
      status: 'started',
      proxy: nil,
      dry_run: false
      )
      
      uri = URI.parse(::Rollbar::Deploy::ENDPOINT)

      request = Net::HTTP::Post.new(uri.request_uri)
      request.body = ::JSON.dump({
        :access_token => access_token,
        :environment => environment,
        :revision => revision,
        :rollbar_username => rollbar_username,
        :local_username => local_username,
        :comment => comment,
        :status => status.to_s
      })
      
      result = self.send_request(uri, proxy, request, dry_run)
      
      if result[:response].is_a? Net::HTTPSuccess
        result[:deploy_id] = JSON.parse(result[:response].body)['data']['deploy_id']
      end
      
      result
    end
    
    def self.update(
      deploy_id:,
      access_token:,
      status:,
      comment: nil,
      proxy: nil,
      dry_run: false
      )
      
      uri = URI.parse(
        ::Rollbar::Deploy::ENDPOINT + 
        deploy_id.to_s +
        "?access_token=" + access_token
      )

      request = Net::HTTP::Patch.new(uri.request_uri)
      request.body = ::JSON.dump({
        :status => status.to_s,
        :comment => comment
      })
      
      self.send_request(uri, proxy, request, dry_run)
    end
      
  private
    
    def self.send_request(uri, proxy, request, dry_run)
      Net::HTTP.start(uri.host, uri.port, proxy, :use_ssl => true) do |http|
        
        result = {
          request_info: uri.inspect + ": " + request.body,
          request: request
        }
        
        unless dry_run
          response = http.request(request)
          
          result[:response] = response
          result[:response_info] = 
            response.code + "; " + 
            response.message + "; " + 
            response.body.delete!("\n")
        end
        
        result
      end
    end
    
    module Capistrano
      
      def self.load_into(configuration)
        configuration.load do
          after 'deploy',            'rollbar:deploy'
          after 'deploy:migrations', 'rollbar:deploy'
          after 'deploy:cold',       'rollbar:deploy'
  
          namespace :rollbar do
            desc 'Send the deployment notification to Rollbar.'
            task :deploy, :except => { :no_release => true } do
              require 'net/http'
              require 'rubygems'
              require 'json'
  
              _cset(:rollbar_user)  { ENV['USER'] || ENV['USERNAME'] }
              _cset(:rollbar_env)   { fetch(:rails_env, 'production') }
              _cset(:rollbar_token) { abort("Please specify the Rollbar access token, set :rollbar_token, 'your token'") }
  
              unless configuration.dry_run
                uri = URI.parse('https://api.rollbar.com/api/1/deploy/')
  
                params = {
                  :local_username => rollbar_user,
                  :access_token => rollbar_token,
                  :environment => rollbar_env,
                  :revision => current_revision
                }
  
                request = Net::HTTP::Post.new(uri.request_uri)
                request.body = ::JSON.dump(params)
  
                Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
                  http.request(request)
                end
              end
  
              logger.info('Rollbar notification complete')
            end
          end
        end
      end
    end
  end
end