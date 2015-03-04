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
             when /sinatra/
               "spec/sinatra"
             when /base/
               "spec/rollbar"
             else
               fail('Please set BUNDLE_GEMFILE to a gemfile inside ./gemfiles')
             end

  system "bundle", "exec", "rspec", "--color", spec_dir or fail
end

task :default => :spec
