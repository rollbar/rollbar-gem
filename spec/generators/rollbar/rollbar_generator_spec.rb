require 'spec_helper'

begin
  require 'generator_spec'
rescue LoadError
  # Skip loading
end

require 'generators/rollbar/rollbar_generator'

unless Rails::VERSION::STRING.start_with?('3.0')
  describe Rollbar::Generators::RollbarGenerator, :type => :generator do
    destination File.expand_path('../../../tmp', __FILE__)

    before { prepare_destination }

    context 'with no arguments' do
      before do
        run_generator
      end

      it 'outputs a help message and generates Rollbar initializer with ENV' do
        expect(destination_root).to have_structure {
          directory 'config' do
            directory 'initializers' do
              file 'rollbar.rb' do
                contains "config.access_token = ENV\['ROLLBAR_ACCESS_TOKEN'\]"
              end
            end
          end
        }
      end
    end

    context 'with arguments' do
      before do
        run_generator(%w[aaaabbbbccccddddeeeeffff00001111])
      end

      it 'generates a Rollbar initializer with access token' do
        expect(destination_root).to have_structure {
          directory 'config' do
            directory 'initializers' do
              file 'rollbar.rb' do
                contains 'aaaabbbbccccddddeeeeffff00001111'
                contains "config.access_token = 'aaaabbbbccccddddeeeeffff00001111'"
              end
            end
          end
        }
      end
    end
  end
end
