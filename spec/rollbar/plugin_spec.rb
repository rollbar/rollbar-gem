require 'spec_helper'
require 'rollbar/plugin'

describe Rollbar::Plugin do
  subject { described_class.new(:plugin) }

  before { subject.instance_eval(&plugin_proc) }

  describe '#load_scoped!' do
    let(:dummy_object) { 'foo' }
    let(:plugin_proc) do
      dummy = dummy_object

      proc do
        execute do
          dummy.upcase
        end

        revert do
          dummy.downcase
        end
      end
    end

    it 'executes provided block in the scope of the plugin' do
      expect(dummy_object).to receive(:upcase).ordered
      expect(dummy_object).to receive(:reverse!).ordered
      expect(dummy_object).to receive(:downcase).ordered

      subject.load_scoped! do
        dummy_object.reverse!
      end
    end

    context 'when called as transparent' do
      it 'loads the plugin and executes the block' do
        expect(dummy_object).to receive(:upcase).ordered
        expect(dummy_object).to receive(:reverse!).ordered
        expect(dummy_object).to receive(:downcase).ordered

        subject.load_scoped!(true) do
          dummy_object.reverse!
        end
      end
    end

    context 'with false dependencies' do
      let(:dummy_object) { '' }
      let(:plugin_proc) do
        dummy = dummy_object

        proc do
          dependency do
            true
          end

          dependency do
            1 == 2.0
          end

          execute do
            dummy.upcase
          end

          execute do
            dummy.downcase
          end
        end
      end

      it 'doesn\'t execute the provided block' do
        expect(dummy_object).to_not receive(:upcase)
        expect(dummy_object).to_not receive(:reverse!)
        expect(dummy_object).to_not receive(:downcase)

        subject.load_scoped! do
          dummy_object.reverse!
        end
      end

      context 'when called as transparent' do
        it "executes provided block and doesn't load the plugin" do
          expect(dummy_object).to_not receive(:upcase)
          expect(dummy_object).to receive(:reverse!)
          expect(dummy_object).to_not receive(:downcase)

          subject.load_scoped!(true) do
            dummy_object.reverse!
          end
        end
      end
    end
  end

  describe '#unload!' do
    context 'with reversal callables' do
      let(:dummy_object) { '' }
      let(:plugin_proc) do
        dummy = dummy_object

        proc do
          revert do
            dummy.upcase
          end
        end
      end

      before { subject.load! }

      it 'unloads the plugin' do
        expect(dummy_object).to receive(:upcase)

        subject.unload!

        expect(subject.loaded).to be_eql(false)
      end

      context 'with exceptions thrown in the reversals' do
        let(:plugin_proc) do
          proc do
            revert do
              raise StandardError
            end
          end
        end

        it 'it logs a plugin unload error message' do
          expect(::Rollbar).to receive(:log_error)
            .with(/Error trying to unload plugin/)

          subject.unload!
        end
      end
    end
  end

  describe '#load!' do
    context 'with requires passing' do
      let(:dummy_object) { '' }
      let(:plugin_proc) do
        dummy = dummy_object

        proc do
          require_dependency('rollbar')
          dependency do
            true
          end

          execute do
            dummy.upcase
          end

          execute do
            dummy.downcase
          end
        end
      end

      it 'loads the plugin' do
        expect(dummy_object).to receive(:upcase)
        expect(dummy_object).to receive(:downcase)

        subject.load!

        expect(subject.loaded).to be_eql(true)
      end
    end

    context 'with requires not passing' do
      let(:dummy_object) { '' }
      let(:plugin_proc) do
        dummy = dummy_object

        proc do
          require_dependency('sure-this-doesnt-exists')
          dependency do
            true
          end

          execute do
            dummy.upcase
          end

          execute do
            dummy.downcase
          end
        end
      end

      it 'doesnt finish loading the plugin' do
        expect(dummy_object).not_to receive(:upcase)
        expect(dummy_object).not_to receive(:downcase)

        subject.load!

        expect(subject.loaded).to be_eql(false)
      end
    end

    context 'with true dependencies' do
      let(:dummy_object) { '' }
      let(:plugin_proc) do
        dummy = dummy_object

        proc do
          dependency do
            true
          end

          dependency do
            1 == 1.0
          end

          execute do
            dummy.upcase
          end

          execute do
            dummy.downcase
          end
        end
      end

      it 'calls the callables' do
        expect(dummy_object).to receive(:upcase).once
        expect(dummy_object).to receive(:downcase).once

        subject.load!

        expect(subject.loaded).to be_eql(true)
      end
    end

    context 'with dependencies failing' do
      let(:dummy_object) { '' }
      let(:plugin_proc) do
        dummy = dummy_object

        proc do
          dependency do
            true
          end

          dependency do
            raise StandardError, 'the-error'
          end

          execute do
            dummy.upcase
          end

          execute do
            dummy.downcase
          end
        end
      end

      it 'doesnt finish loading the plugin' do
        expect(dummy_object).not_to receive(:upcase)
        expect(dummy_object).not_to receive(:downcase)
        expect(Rollbar)
          .to receive(:log_error)
          .with("Error trying to load plugin 'plugin': StandardError, the-error")

        subject.load!

        expect(subject.loaded).to be_eql(false)
      end
    end

    context 'with callables failing' do
      let(:dummy_object) { '' }
      let(:plugin_proc) do
        dummy = dummy_object

        proc do
          dependency do
            true
          end

          dependency do
            1 == 1.0
          end

          execute do
            raise StandardError, 'the-error'
          end

          execute do
            dummy.downcase
          end
        end
      end

      it 'doesnt finish loading the plugin' do
        expect(dummy_object).not_to receive(:downcase)
        expect(Rollbar)
          .to receive(:log_error)
          .with("Error trying to load plugin 'plugin': StandardError, the-error")

        subject.load!

        expect(subject.loaded).to be_eql(true)
      end
    end

    context 'with false dependencies' do
      let(:dummy_object) { '' }
      let(:plugin_proc) do
        dummy = dummy_object

        proc do
          dependency do
            true
          end

          dependency do
            1 == 2.0
          end

          execute do
            dummy.upcase
          end

          execute do
            dummy.downcase
          end
        end
      end

      it 'calls the callables' do
        expect(dummy_object).not_to receive(:upcase)
        expect(dummy_object).not_to receive(:downcase)

        subject.load!

        expect(subject.loaded).to be_eql(false)
      end
    end
  end
end
