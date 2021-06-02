require 'spec_helper'
require 'rollbar/plugins/resque/failure'

describe Resque::Failure::Rollbar do
  let(:exception) { StandardError.new('BOOM') }
  let(:worker) { Resque::Worker.new(:test) }
  let(:queue) { 'test' }
  let(:payload) { { 'class' => Object, 'args' => 89 } }
  let(:backend) do
    Resque::Failure::Rollbar.new(exception, worker, queue, payload)
  end

  context 'with Rollbar version <= 1.3' do
    before do
      allow(backend).to receive(:rollbar_version).and_return('1.3.0')
    end

    it 'should be notified of an error' do
      expect_any_instance_of(Rollbar::Notifier).to receive(:log).with('error', exception,
                                                                      payload)
      backend.save
    end
  end

  context 'with Rollbar version > 1.3' do
    let(:payload_with_options) { payload.merge(:use_exception_level_filters => true) }

    before do
      allow(backend).to receive(:rollbar_version).and_return('1.4.0')
    end

    it 'sends the :use_exception_level_filters option' do
      expect_any_instance_of(Rollbar::Notifier).to receive(:error).with(exception,
                                                                        payload_with_options)
      backend.save
    end
  end
end
