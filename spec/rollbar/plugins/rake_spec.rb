require 'spec_helper'

Rollbar.plugins.load!

describe Rollbar::Rake do
  let(:application) { Rake.application }
  let(:exception) { Exception.new }

  context 'with supported rake version' do
    before do
      allow(Rollbar::Rake).to receive(:rake_version).and_return('0.9.0')
    end

    it 'reports error to Rollbar' do
      expect(Rollbar).to receive(:error).with(exception, :use_exception_level_filters => true)
      expect(application).to receive(:orig_display_error_message).with(exception)

      Rollbar::Rake.patch! # Really here Rake is already patched
      application.display_error_message(exception)
    end
  end

  context 'with unsupported rake version' do
    before do
      allow(Rollbar::Rake).to receive(:rake_version).and_return('0.8.7')
    end

    it 'reports error to Rollbar' do
      expect(Rollbar::Rake).to receive(:skip_patch)

      Rollbar::Rake.patch!
    end
  end
end
