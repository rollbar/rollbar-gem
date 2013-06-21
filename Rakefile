#!/usr/bin/env rake
require 'rubygems'
require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'appraisal'

RSpec::Core::RakeTask.new(:spec)

namespace :dummy do
  load 'spec/dummyapp/Rakefile'
end

desc 'Run specs'
task :default => ['dummy:db:setup'] do
  ENV['LOCAL'] = '1'
  Rake::Task[:spec].invoke
  
  Rake::Task[:spec].reenable
  
  ENV['LOCAL'] = '0'
  Rake::Task[:spec].invoke
end