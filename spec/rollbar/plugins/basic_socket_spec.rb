require 'spec_helper'
require 'rollbar'
require 'socket'

Rollbar.plugins.load!

shared_examples 'unloadable' do
  it "doesn't load" do
    subject.load!
    expect(subject.loaded).to eq(false)
  end
end

describe 'basic_socket plugin' do
  subject { Rollbar.plugins.get('basic_socket') }

  before(:all) do
    Rollbar.plugins.get('basic_socket').unload!
  end

  after(:each) do
    subject.unload!
  end

  it 'is an on demand plugin' do
    expect(subject.on_demand).to eq(true)
  end

  it "doesn't load by default" do
    expect(subject.loaded).to eq(false)
  end

  describe '#load_scoped!' do
    context 'with core monkey patching enabled' do
      before { subject.configuration.disable_core_monkey_patch = false }

      if Gem::Version.new(ActiveSupport::VERSION::STRING) < Gem::Version.new('4.1.0')
        context 'using active_support < 4.1' do
          it 'changes implementation of ::BasicSocket#as_json temporarily' do
            original_implementation = BasicSocket
                                      .public_instance_method(:as_json)
                                      .source_location

            subject.load_scoped! do
              expect(subject.loaded).to eq(true)
              socket = TCPSocket.new 'example.com', 80
              expect(socket.as_json).to include(:value)
              expect(socket.as_json[:value]).to match(/TCPSocket/)
            end

            expect(subject.loaded).to eq(false)
            expect(BasicSocket.public_instance_method(:as_json).source_location)
              .to(eq(original_implementation))
          end
        end
      else
        context 'using active_support >= 4.1' do
          context 'when called as transparent' do
            it 'executes provided block even when dependencies are unmet' do
              result = false
              subject.load_scoped!(true) do
                result = true
                expect(subject.loaded).to eq(false) # Plugin should not load
              end
              expect(result).to eq(true)
              expect(subject.loaded).to eq(false)
            end
          end
        end
      end
    end
  end

  describe '#load!' do
    if Gem::Version.new(ActiveSupport::VERSION::STRING) < Gem::Version.new('4.1.0')
      context 'using active_support < 4.1' do
        context 'with core monkey patching enabled' do
          before { subject.configuration.disable_core_monkey_patch = false }

          it 'loads' do
            subject.load!
            expect(subject.loaded).to eq(true)

            subject.unload!
            expect(subject.loaded).to eq(false)
          end

          it 'changes implementation of ::BasicSocket#as_json' do
            subject.load!
            socket = TCPSocket.new 'example.com', 80
            expect(socket.as_json).to include(:value)
            expect(socket.as_json[:value]).to match(/TCPSocket/)

            subject.unload!
            expect(subject.loaded).to eq(false)
          end
        end

        context 'with core monkey patching disabled' do
          before { subject.configuration.disable_core_monkey_patch = true }

          it_should_behave_like 'unloadable'
        end
      end
    else
      context 'using active_support >= 4.1' do
        it_should_behave_like 'unloadable'
      end
    end
  end
end
