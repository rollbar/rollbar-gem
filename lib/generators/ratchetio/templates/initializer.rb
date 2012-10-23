require 'ratchetio/rails'
Ratchetio.configure do |config|
  config.access_token = <%= access_token_expr %>

  # Add exception class names to the exception_level_filters hash to
  # change the level that exception is reported at. Note that if an exception
  # has already been reported and logged the level will need to be changed
  # via the ratchet.io interface.
  # config.exception_level_filters.merge!('MyCriticalException' => 'critical')
end
