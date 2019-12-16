require 'spec_helper'
require 'tempfile'
require 'rollbar/item/backtrace'
require 'rollbar/item/frame'

describe Rollbar::Item::Frame do
  subject { described_class.new(backtrace, frame, options) }

  let(:backtrace) { double('backtrace') }
  let(:options) { {} }

  describe '#to_h' do
    context 'with a frame that is not a valid frame' do
      let(:frame) { 'this frame is not valid' }

      it 'return an unknown frame value' do
        expected_result = {
          :filename => '<unknown>',
          :lineno => 0,
          :method => frame
        }

        result = subject.to_h
        expect(result).to be_eql(expected_result)
      end
    end

    context 'with valid frame' do
      let(:file) do
        <<-END
foo1
foo2
foo3
foo4
foo5
foo6
foo7
foo8
foo9
foo10
foo11
foo12
foo13
        END
      end
      let(:filepath) do
        '/var/www/rollbar/playground/rails4.2/vendor/bundle/gems/actionpack-4.2.0/lib/action_controller/metal/implicit_render.rb'
      end
      let(:frame) do
        "#{filepath}:7:in `send_action'"
      end
      let(:options) do
        { :configuration => configuration }
      end

      before do
        allow(backtrace).to receive(:get_file_lines).with(filepath).and_return(file.split("\n"))
      end

      context 'with send_extra_frame_data = :none' do
        let(:configuration) do
          double('configuration',
                 :send_extra_frame_data => :none,
                 :locals => {},
                 :root => '/var/www')
        end

        it 'just return the filename, lineno and method' do
          expected_result = {
            :filename => filepath,
            :lineno => 7,
            :method => 'send_action'
          }

          expect(subject.to_h).to be_eql(expected_result)
        end
      end

      context 'with send_extra_frame_data = :all' do
        let(:configuration) do
          double('configuration',
                 :send_extra_frame_data => :all,
                 :locals => {},
                 :root => '/var/www')
        end

        it 'returns also code and context' do
          expected_result = {
            :filename => filepath,
            :lineno => 7,
            :method => 'send_action',
            :code => 'foo7',
            :context => {
              :pre => %w[foo3 foo4 foo5 foo6],
              :post => %w[foo8 foo9 foo10 foo11]
            },
            :locals => nil
          }

          expect(subject.to_h).to be_eql(expected_result)
        end

        context 'if there is not lines in the file' do
          let(:file) do
            ''
          end
          it 'just returns the basic data' do
            expected_result = {
              :filename => filepath,
              :lineno => 7,
              :method => 'send_action'
            }

            expect(subject.to_h).to be_eql(expected_result)
          end
        end

        context 'if the file couldnt be read' do
          before do
            allow(backtrace).to receive(:get_file_lines).with(filepath).and_return(nil)
          end

          it 'just returns the basic data' do
            expected_result = {
              :filename => filepath,
              :lineno => 7,
              :method => 'send_action'
            }

            expect(subject.to_h).to be_eql(expected_result)
          end
        end
      end

      context 'with send_extra_frame_data = :app' do
        context 'with frame outside the root' do
          let(:configuration) do
            double('configuration',
                   :send_extra_frame_data => :app,
                   :locals => {},
                   :root => '/outside/project',
                   :project_gem_paths => [])
          end

          it 'just returns the basic frame data' do
            expected_result = {
              :filename => filepath,
              :lineno => 7,
              :method => 'send_action'
            }

            expect(subject.to_h).to be_eql(expected_result)
          end
        end

        context 'with frame inside project_gem_paths' do
          let(:configuration) do
            double('configuration',
                   :send_extra_frame_data => :app,
                   :locals => {},
                   :root => '/var/outside/',
                   :project_gem_paths => ['/var/www/'])
          end

          it 'returns also context and code data' do
            expected_result = {
              :filename => filepath,
              :lineno => 7,
              :method => 'send_action',
              :code => 'foo7',
              :context => {
                :pre => %w[foo3 foo4 foo5 foo6],
                :post => %w[foo8 foo9 foo10 foo11]
              },
              :locals => nil
            }

            expect(subject.to_h).to be_eql(expected_result)
          end
        end

        context 'and frame inside app root' do
          let(:configuration) do
            double('configuration',
                   :send_extra_frame_data => :app,
                   :locals => {},
                   :root => '/var/www',
                   :project_gem_paths => [])
          end

          it 'returns also the context and code data' do
            expected_result = {
              :filename => filepath,
              :lineno => 7,
              :method => 'send_action',
              :code => 'foo7',
              :context => {
                :pre => %w[foo3 foo4 foo5 foo6],
                :post => %w[foo8 foo9 foo10 foo11]
              },
              :locals => nil
            }

            expect(subject.to_h).to be_eql(expected_result)
          end

          context 'but inside Gem.path' do
            let(:configuration) do
              double('configuration',
                     :send_extra_frame_data => :app,
                     :locals => {},
                     :root => '/var/www/',
                     :project_gem_paths => [])
            end

            before do
              allow(Gem).to receive(:path).and_return(['/var/www/rollbar'])
            end

            it 'just returns also the basic data' do
              expected_result = {
                :filename => filepath,
                :lineno => 7,
                :method => 'send_action'
              }

              expect(subject.to_h).to be_eql(expected_result)
            end
          end

          context 'having less pre lines than maximum' do
            let(:frame) do
              "#{filepath}:3:in `send_action'"
            end

            it 'returns up to 2 pre lines' do
              expected_result = {
                :filename => filepath,
                :lineno => 3,
                :method => 'send_action',
                :code => 'foo3',
                :context => {
                  :pre => %w[foo1 foo2],
                  :post => %w[foo4 foo5 foo6 foo7]
                },
                :locals => nil
              }

              expect(subject.to_h).to be_eql(expected_result)
            end
          end

          context 'having less post lines than maximum' do
            let(:frame) do
              "#{filepath}:11:in `send_action'"
            end

            it 'returns up to 2 post lines' do
              expected_result = {
                :filename => filepath,
                :lineno => 11,
                :method => 'send_action',
                :code => 'foo11',
                :context => {
                  :pre => %w[foo7 foo8 foo9 foo10],
                  :post => %w[foo12 foo13]
                },
                :locals => nil
              }

              expect(subject.to_h).to be_eql(expected_result)
            end
          end
        end
      end
    end
  end
end
