Rollbar.configure do |config|
  config.access_token = 'aaaabbbbccccddddeeeeffff00001111'
  config.open_timeout = 60
  config.request_timeout = 60
  config.js_enabled = true
  config.js_options = {
    :foo => :bar
  }
  # By default, Rollbar will try to call the `current_user` controller method
  # to fetch the logged-in user object, and then call that object's `id` and
  # `username` methods to fetch those properties. To customize:
  # config.person_method = "my_current_user"
  # config.person_id_method = "my_id"
  # config.person_username_method = "my_username"

  # Additionally, if you're happy to send Rollbar personally identifiable information...
  # config.person_email_method = "email"

  # Add exception class names to the exception_level_filters hash to
  # change the level that exception is reported at. Note that if an exception
  # has already been reported and logged the level will need to be changed
  # via the rollbar interface.
  # Valid levels: 'critical', 'error', 'warning', 'info', 'debug', 'ignore'
  # 'ignore' will cause the exception to not be reported at all.
  # config.exception_level_filters.merge!('MyCriticalException' => 'critical')
end
