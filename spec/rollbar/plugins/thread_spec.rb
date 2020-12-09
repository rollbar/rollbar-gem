require 'spec_helper'

Rollbar.plugins.load!

describe Rollbar::ThreadPlugin do
  subject(:thread) { Thread.new {} }

  it 'has a Rollbar notifier' do
    expect(thread[:_rollbar_notifier]).to be_a_kind_of(Rollbar::Notifier)
  end
end
