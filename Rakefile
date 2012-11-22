#!/usr/bin/env rake
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

namespace :dummy do
  load 'spec/dummyapp/Rakefile'
end

desc 'Run specs'
task :default => ['dummy:db:setup'] do
  Rake::Task[:spec].invoke
end
