require 'spec_helper'

begin
  require 'genspec'
rescue LoadError
end

require 'generators/rollbar/rollbar_generator'

if Rails::VERSION::STRING.start_with?('3.0')
  describe :rollbar do
    context 'with no arguments' do
      it 'outputs a help message' do
        subject.should output(/You'll need to add an environment variable ROLLBAR_ACCESS_TOKEN with your access token/)
      end

      it 'generates a Rollbar initializer with ENV' do
        subject.should generate('config/initializers/rollbar.rb') { |content|
          content.should =~ /config.access_token = ENV\['ROLLBAR_ACCESS_TOKEN'\]/
        }
      end
    end

    with_args 'aaaabbbbccccddddeeeeffff00001111' do
      it 'generates a Rollbar initializer with access token' do
        subject.should generate('config/initializers/rollbar.rb') do |content|
          content.should =~ /aaaabbbbccccddddeeeeffff00001111/
          content.should =~ /config.access_token = 'aaaabbbbccccddddeeeeffff00001111'/
        end
      end
    end
  end
end
