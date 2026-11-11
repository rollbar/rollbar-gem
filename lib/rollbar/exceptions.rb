module Rollbar
  class Ignore < StandardError; end

  # Carries a reported message and its caller backtrace when
  # `populate_message_backtraces` is enabled. It is never raised; its class name
  # identifies these items in Rollbar.
  class ReportedMessage < StandardError; end
end
