require 'capistrano'

module Rollbar
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
            _cset(:rollbar_comment) { fetch(:rollbar_comment) }

            unless configuration.dry_run
              uri = URI.parse('https://api.rollbar.com/api/1/deploy/')

              params = {
                :local_username => rollbar_user,
                :access_token => rollbar_token,
                :environment => rollbar_env,
                :revision => current_revision,
                :comment => rollbar_comment
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

if Capistrano::Configuration.instance
  Rollbar::Capistrano.load_into(Capistrano::Configuration.instance)
end
