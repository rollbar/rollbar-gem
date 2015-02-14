#!/usr/bin/env rake
require 'rubygems'
require 'bundler/setup'
require 'bundler/gem_tasks'
require 'appraisal'

desc "Run specs for loaded version of rails"
task :spec do
  spec_dir = case ENV['BUNDLE_GEMFILE']
             when /rails/
               "spec/rails"
             when /base/
               "spec/rollbar"
             else
               fail('Please set BUNDLE_GEMFILE to a gemfile inside ./gemfiles')
             end

  system "bundle", "exec", "rspec", "--color", spec_dir
end

#
# RSpec::Core::RakeTask.new(:spec)
#
# desc 'Run specs'
# task :default do
#   ENV['LOCAL'] = '1'
#   Rake::Task[:spec].invoke
#
#   Rake::Task[:spec].reenable
#
#   ENV['LOCAL'] = '0'
#   Rake::Task[:spec].invoke
# end
