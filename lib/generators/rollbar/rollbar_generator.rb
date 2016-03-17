require 'rails/generators'
require 'rails/generators/named_base'
require 'generators/rollbar/rollbar_generator'

module Rollbar
  module Generators
    class RollbarGenerator < ::Rails::Generators::Base
      argument :access_token, :type => :string, :banner => 'access_token', :default => :use_env_sentinel

      source_root File.expand_path(File.join(File.dirname(__FILE__), 'templates'))

      def create_initializer
        say "creating initializer..."
        if access_token_configured?
          say "It looks like you've already configured Rollbar."
          say "To re-create the config file, remove it first: config/initializers/rollbar.rb"
          exit
        end

        begin
          require 'ey_config'
        rescue LoadError
        end
        
        if defined? EY::Config
            say "Access token will be read from Engine Yard configuration"
        else
          if access_token === :use_env_sentinel
            say "Generator run without an access token; assuming you want to configure using an environment variable."
            say "You'll need to add an environment variable ROLLBAR_ACCESS_TOKEN with your access token:"
            say "\n$ export ROLLBAR_ACCESS_TOKEN=yourtokenhere"
            say "\nIf that's not what you wanted to do:"
            say "\n$ rm config/initializers/rollbar.rb"
            say "$ rails generate rollbar yourtokenhere"
            say "\n"
          else
            say "access token: " << access_token
          end
        end

        template 'initializer.rb', 'config/initializers/rollbar.rb',
          :assigns => { :access_token => access_token_expr }

        # TODO run rake test task
      end

      def access_token_expr
        if access_token === :use_env_sentinel
          "ENV['ROLLBAR_ACCESS_TOKEN']"
        else
          "'#{access_token}'"
        end
      end

      def access_token_configured?
        File.exists?('config/initializers/rollbar.rb')
      end
    end
  end
end
