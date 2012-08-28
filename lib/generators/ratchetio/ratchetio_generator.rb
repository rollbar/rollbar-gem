require 'rails/generators'
require 'rails/generators/named_base'

module Ratchetio
  module Generators
    class RatchetioGenerator < ::Rails::Generators::Base
      argument :access_token, :type => :string, :banner => "access_token"

      source_root File.expand_path(File.join(File.dirname(__FILE__), 'templates'))

      def create_initializer
        puts "creating initializer..."
        if access_token_configured?
          puts "It looks like you've already configured Ratchetio."
          puts "To re-create the config file, remove it first: config/initializers/ratchetio.rb"
          exit
        end

        puts "access token: " << access_token

        template 'initializer.rb', 'config/initializers/ratchetio.rb',
          :assigns => { :access_token => access_token_expr }

        # TODO run rake test task
      end

      #def add_options!(opt)
      #  opt.on('-a', '--access-token=token', String, "Your Ratchet.io project access token") { |v| options[:access_token] = v }
      #end
#
#      def manifest
#        if !access_token_configured? && !options[:access_token]
#          puts "access_token is required. Pass --access-token=YOUR_ACCESS_TOKEN"
#          exit
#        end
#        
#        record do |m|
#          m.template 'initializer.rb', 'config/initializers/ratchetio.rb',
#            :assigns => { :access_token => access_token_expr }
#          # TODO run rake test task
#        end
#      end

      def access_token_expr
        "'#{access_token}'"
      end

      def access_token_configured?
        File.exists?('config/initializers/ratchetio.rb')
      end
    end
  end
end
