require 'spec_helper'
require 'rollbar'

Rollbar.plugins.load!

describe Rollbar::ActiveRecordExtension do
  it 'has the extensions loaded into ActiveRecord::Base' do
    expect(ActiveRecord::Base.ancestors).to include(described_class)
    expect(ActiveRecord::Base.instance_methods.map(&:to_sym)).to include(:report_validation_errors_to_rollbar)
  end
end
