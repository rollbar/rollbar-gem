require 'spec_helper'
require 'rollbar/plugin'

describe Rollbar::Plugin do
  describe '#load!' do
    subject { described_class.new(:plugin) }

    before { subject.instance_eval(&plugin_proc) }

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
            raise StandardError.new('the-error')
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
        expect(Rollbar).to receive(:log_error).with("Error trying to load plugin 'plugin': StandardError, the-error")

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
            raise StandardError.new('the-error')
          end

          execute do
            dummy.downcase
          end
        end
      end

      it 'doesnt finish loading the plugin' do
        expect(dummy_object).not_to receive(:downcase)
        expect(Rollbar).to receive(:log_error).with("Error trying to load plugin 'plugin': StandardError, the-error")

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
