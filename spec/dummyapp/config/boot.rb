require 'rubygems'

# If not already set, use the default.
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../../../Gemfile', __FILE__)

if File.exist?(ENV['BUNDLE_GEMFILE'])
  require 'bundler'
  Bundler.setup
end

$LOAD_PATH.unshift File.expand_path('../../../../lib', __FILE__)
