require 'capistrano'
require 'rollbar/deploy'

if Capistrano::Configuration.instance
  Rollbar::Deploy::Capistrano.load_into(Capistrano::Configuration.instance)
end
