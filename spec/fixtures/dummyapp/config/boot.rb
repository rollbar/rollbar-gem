require 'rubygems'
require 'bundler'
Bundler.setup

# gemfile = File.expand_path('../../../../Gemfile', __FILE__)
#
# if File.exist?(gemfile)
#   ENV['BUNDLE_GEMFILE'] = gemfile
# end

$:.unshift File.expand_path('../../../../lib', __FILE__)
