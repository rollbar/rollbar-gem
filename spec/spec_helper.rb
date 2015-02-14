require_relative './support/fixture_helpers'
require_relative './support/notifier_helpers'
require_relative './support/shared_contexts'

RSpec.configure do |config|
  config.include(NotifierHelpers)
  config.include(FixtureHelpers)
end
