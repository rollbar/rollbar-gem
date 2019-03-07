require 'spec_helper'
require 'rollbar'

Rollbar.plugins.load!

shared_examples 'unloadable' do
  it "doesn't load" do
    subject.load!
    expect(subject.loaded).to eq(false)
  end
end

describe 'basic_socket plugin' do
  subject { Rollbar.plugins.get('basic_socket') }

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

      if Gem::Version.new(ActiveSupport::VERSION::STRING) < Gem::Version.new('5.2.0')
        context 'using active_support < 5.2' do
          it 'changes implementation of ::BasicSocket#as_json temporarily' do
            original_implementation = BasicSocket.public_instance_method(:as_json)

            subject.load_scoped! do
              socket = TCPSocket.new 'example.com', 80
              expect(JSON.parse(socket.as_json)).to include('value')
              expect(JSON.parse(socket.as_json)['value']).to match(/TCPSocket/)
            end

            expect(BasicSocket.public_instance_method(:as_json)).to eq(original_implementation)
          end
        end
      else
        context 'using active_support >= 5.2' do
          context 'when called as transparent' do
            it 'executes provided block even when depencies are unmet' do
              result = false
              subject.load_scoped!(true) do
                result = true
              end
              expect(result).to eq(true)
            end
          end
        end
      end
    end
  end

  describe '#load!' do
    if Gem::Version.new(ActiveSupport::VERSION::STRING) < Gem::Version.new('5.2.0')
      context 'using active_support < 5.2' do
        context 'with core monkey patching enabled' do
          before { subject.configuration.disable_core_monkey_patch = false }

          it 'loads' do
            subject.load!
            expect(subject.loaded).to eq(true)
          end

          it 'changes implementation of ::BasicSocket#as_json' do
            subject.load!
            socket = TCPSocket.new 'example.com', 80
            expect(JSON.parse(socket.as_json)).to include('value')
            expect(JSON.parse(socket.as_json)['value']).to match(/TCPSocket/)
          end
        end

        context 'with core monkey patching disabled' do
          before { subject.configuration.disable_core_monkey_patch = true }

          it_should_behave_like 'unloadable'
        end
      end
    else
      context 'using active_support >= 5.2' do
        it_should_behave_like 'unloadable'
      end
    end
  end
end
