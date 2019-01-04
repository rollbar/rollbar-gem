require 'capistrano'
require 'rollbar/deploy/capistrano'

if Capistrano::Configuration.instance
  Rollbar::Capistrano.load_into(Capistrano::Configuration.instance)
end
