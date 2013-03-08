# Rollbar [![Build Status](https://secure.travis-ci.org/rollbar/rollbar-gem.png?branch=master)](https://travis-ci.org/rollbar/rollbar-gem)

Ruby gem for reporting exceptions, errors, and log messages to [Rollbar](https://rollbar.com). Requires a Rollbar account (you can [sign up for free](https://rollbar.com/signup)). Basic integration in a Rails 3 app should only take a few minutes.

## Installation

Add this line to your application's Gemfile:

    gem 'rollbar'

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install rollbar

Then, run the following command from your rails root:

    $ rails generate rollbar YOUR_ROLLBAR_PROJECT_ACCESS_TOKEN

That will create the file `config/initializers/rollbar.rb`, which holds the configuration values (currently just your access token) and is all you need to use Rollbar with Rails.

To confirm that it worked, run:

    $ rake rollbar:test

This will raise an exception within a test request; if it works, you'll see a stacktrace in the console, and the exception will appear in the Rollbar dashboard.

## Manually reporting exceptions and messages

To report a caught exception to Rollbar, simply call `Rollbar.report_exception`:

```ruby
begin
  foo = bar
rescue Exception => e
  Rollbar.report_exception(e)
end
```

If you're reporting an exception in the context of a request and are in a controller, you can pass along the same request and person context as the global exception handler, like so:

```ruby
begin
  foo = bar
rescue Exception => e
  Rollbar.report_exception(e, rollbar_request_data, rollbar_person_data)
end
```

You can also log individual messages:

```ruby
# logs at the 'warning' level. all levels: debug, info, warning, error, critical
Rollbar.report_message("Unexpected input", "warning")

# default level is "info"
Rollbar.report_message("Login successful")

# can also include additional data as a hash in the final param. :body is reserved.
Rollbar.report_message("Login successful", "info", :user => @user)
```


## Person tracking

Rollbar will send information about the current user (called a "person" in Rollbar parlance) along with each error report, when available. This works by calling the `current_user` controller method. The return value should be an object with an `id` method and, optionally, `username` and `email` methods.

If the gem should call a controller method besides `current_user`, add the following in `config/initializers/rollbar.rb`:

```ruby
  config.person_method = "my_current_user"
```

If the methods to extract the `id`, `username`, and `email` from the object returned by the `person_method` have other names, configure like so in `config/initializers/rollbar.rb`:

```ruby
  config.person_id_method = "user_id"  # default is "id"
  config.person_username_method = "user_name"  # default is "username"
  config.person_email_method = "email_address"  # default is "email"
```


## Exception level filters

By default, all exceptions reported through `Rollbar.report_exception()` are reported at the "error" level, except for the following, which are reported at "warning" level:

- ActiveRecord::RecordNotFound
- AbstractController::ActionNotFound
- ActionController::RoutingError

If you'd like to customize this list, see the example code in `config/initializers/rollbar.rb`. Supported levels: "critical", "error", "warning", "info", "debug", "ignore". Set to "ignore" to cause the exception not to be reported at all.


## Silencing exceptions at runtime

If you just want to disable exception reporting for a single block, use `Rollbar.silenced`:

```ruby
Rollbar.silenced {
  foo = bar  # will not be reported
}
```


## Asynchronous reporting

By default, all messages are reported synchronously. You can enable asynchronous reporting by adding the following in `config/initializers/rollbar.rb`:

```ruby
  config.use_async = true
```

Rollbar uses [girl_friday](https://github.com/mperham/girl_friday) to handle asynchronous reporting when installed, and falls back to Threading if girl_friday is not installed.

You can supply your own handler using `config.async_handler`. The handler should schedule the payload for later processing (i.e. with a delayed_job, in a resque queue, etc.) and should itself return immediately. For example:

```ruby
  config.async_handler = Proc.new { |payload|
    Thread.new { Rollbar.process_payload(payload) }
  }
```

Make sure you pass `payload` to `Rollbar.process_payload` in your own implementation.


## Using with rollbar-agent

For even more asynchrony, you can configure the gem to write to a file instead of sending the payload to Rollbar servers directly. [rollbar-agent](https://github.com/rollbar/rollbar-agent) can then be hooked up to this file to actually send the payload across. To enable, add the following in `config/initializers/rollbar.rb`:

```ruby
  config.write_to_file = true
  # optional, defaults to "#{AppName}.rollbar"
  config.filepath = '/path/to/file.rollbar' #should end in '.rollbar' for use with rollbar-agent
```

For this to work, you'll also need to set up rollbar-agent--see its docs for details.


## Deploy Tracking with Capistrano

Add the following to `deploy.rb`:

```ruby
require 'rollbar/capistrano'
set :rollbar_token, 'your-rollbar-project-access-token'
```

Available options:

- `rollbar_token` - the same project access token as you used for the `rails generate rollbar` command; find it in `config/initializers/rollbar.rb`. (It's repeated here for performance reasons, so the rails environment doesn't have to be initialized.)
- `rollbar_env` - deploy environment name, `rails_env` by default

For `capistrano/multistage`, try:

```ruby
set(:rollbar_env) { stage }
```


## Using with Goalie

If you're using [Goalie](https://github.com/obvio171/goalie) for custom error pages, you may need to explicitly add `require 'goalie'` to `config/application.rb` (in addition to `require 'goalie/rails'`) so that the monkeypatch will work. (This will be obvious if it is needed because your app won't start up: you'll see a cryptic error message about `Goalie::CustomErrorPages.render_exception` not being defined.)


## Using with Resque

Check out [resque-ratchetio](https://github.com/CrowdFlower/resque-ratchetio) for using Rollbar as a failure backend for Resque.


## Help / Support

If you run into any issues, please email us at `support@rollbar.com`


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

We're using RSpec for testing. Run the test suite with `rake spec`. Tests for pull requests are appreciated but not required. (If you don't include a test, we'll write one before merging.)
