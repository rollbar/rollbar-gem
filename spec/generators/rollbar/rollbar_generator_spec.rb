require 'spec_helper'

begin
  require 'genspec'
rescue LoadError
end

begin
  require 'generator_spec'
rescue LoadError
end

require 'generators/rollbar/rollbar_generator'

if defined?(GeneratorSpec)
  describe Rollbar::Generators::RollbarGenerator, :type => :generator do
    destination File.expand_path('../../../tmp', __FILE__)

    context 'with no arguments' do
      before do
        prepare_destination
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
        prepare_destination
        run_generator(%w(aaaabbbbccccddddeeeeffff00001111))
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
else
  describe :rollbar do
    context "with no arguments" do
      it "outputs a help message" do
        subject.should output(/You'll need to add an environment variable ROLLBAR_ACCESS_TOKEN with your access token/)
      end

      it "generates a Rollbar initializer with ENV" do
        subject.should generate("config/initializers/rollbar.rb") { |content|
          content.should =~ /config.access_token = ENV\['ROLLBAR_ACCESS_TOKEN'\]/
        }
      end
    end

    with_args 'aaaabbbbccccddddeeeeffff00001111' do
      it "generates a Rollbar initializer with access token" do
        subject.should generate("config/initializers/rollbar.rb") do |content|
          content.should =~ /aaaabbbbccccddddeeeeffff00001111/
          content.should =~ /config.access_token = 'aaaabbbbccccddddeeeeffff00001111'/
        end
      end
    end
  end
end
