require 'spec_helper'

unless RUBY_VERSION == '1.8.7'
  require 'sidekiq'
  require 'rollbar/sidekiq'
end

describe "Sidekiq integration", :reconfigure_notifier => false do
  before{ skip if RUBY_VERSION == '1.8.7' }

  describe "Rollbar::Sidekiq.handle_exception" do
    let(:msg_or_context) { ["hello", "error_backtrace", "backtrace", "goodbye"] }
    let(:exception) { StandardError.new("oh noes") }
    let(:rollbar) { double }
    subject do
      Rollbar::Sidekiq.handle_exception(msg_or_context, exception)
    end

    it "constructs scope from filtered params" do
      rollbar.stub(:error)
      Rollbar.should_receive(:scope).with(
        { :request => { :params => ["hello", "goodbye"] } }
      ) {rollbar}
      subject
    end
    it "sends the passed-in error to rollbar" do
      Rollbar.stub(:scope) { rollbar }
      rollbar.should_receive(:error).with(exception, :use_exception_level_filters => true)
      subject
    end
  end

  describe "middleware" do
    let(:middleware) { Rollbar::Sidekiq.new }
    let(:msg) { ["hello"] }
    let(:exception) { StandardError.new("oh noes") }
    subject do
      middleware.call(nil, msg, nil) do
        raise exception
      end
    end

    it "sends the error to Rollbar::Sidekiq.handle_exception" do
      Rollbar::Sidekiq.should_receive(:handle_exception).with(msg, exception)
      subject rescue nil
    end

    it "re-raises the exception" do
      assert_raises StandardError do
        subject
      end
    end
  end
end
