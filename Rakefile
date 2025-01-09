#!/usr/bin/env rake
require 'rubygems'
require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

desc 'Run specs'
task :default do
  ENV['LOCAL'] = '1'
  Rake::Task[:spec].invoke

  Rake::Task[:spec].reenable

  ENV['LOCAL'] = '0'
  Rake::Task[:spec].invoke
end

Dir.glob('lib/tasks/*.rake').each { |r| load r }
