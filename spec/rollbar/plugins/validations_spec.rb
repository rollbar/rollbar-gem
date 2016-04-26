require 'spec_helper'
require 'rollbar'

Rollbar.plugins.load!

describe Rollbar::ActiveRecordExtension do
  it 'has the extensions loaded into ActiveRecord::Base' do
    expect(ActiveModel::Validations.ancestors).to include(described_class)
    expect(ActiveModel::Validations.instance_methods.map(&:to_sym)).to include(:report_validation_errors_to_rollbar)
  end

  context 'with an ActiveRecord::Base instance' do
    let(:user) { User.new }

    it 'calls report_validation_errors_to_rollbar' do
      expect(user).to receive(:report_validation_errors_to_rollbar)

      user.valid?
    end
  end

  context 'with class using ActiveModel::Validations' do
    let(:post) { Post.new }

    it 'calls report_validation_errors_to_rollbar' do
      expect(post).to receive(:report_validation_errors_to_rollbar)

      post.valid?
    end
  end

  describe '#report_validation_errors_to_rollbar', :reconfigure_notifier => true do
    context 'having validation errors' do
      let(:user) { User.new }

      it 'send the errors to Rollbar' do
        expect(Rollbar).to receive(:warning)

        user.valid?
      end
    end
  end
end
