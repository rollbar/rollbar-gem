require "#{File.dirname(__FILE__)}/support/fixture_helpers"
require "#{File.dirname(__FILE__)}/support/notifier_helpers"
require "#{File.dirname(__FILE__)}/support/shared_contexts"

RSpec.configure do |config|
  config.include(NotifierHelpers)
  config.include(FixtureHelpers)
end
