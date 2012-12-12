# Ratchetio [![Build Status](https://secure.travis-ci.org/ratchetio/ratchetio-gem.png?branch=master)](https://travis-ci.org/ratchetio/ratchetio-gem)

Ruby gem for Ratchet.io, for reporting exceptions in Rails 3 to Ratchet.io. Requires a Ratchet.io account (you can sign up for free).

## Installation

Add this line to your application's Gemfile:

    gem 'ratchetio'

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install ratchetio

Then, run the following command from your rails root:

    $ rails generate ratchetio YOUR_RATCHETIO_PROJECT_ACCESS_TOKEN

That will create the file `config/initializers/ratchetio.rb`, which holds the configuration values (currently just your access token) and is all you need to use Ratchet.io with Rails.

To confirm that it worked, run:

    $ rake ratchetio:test

This will raise an exception within a test request; if it works, you'll see a stacktrace in the console, and the exception will appear in the Ratchet.io dashboard.

## Manually reporting exceptions and messages

To report a caught exception to Ratchet, simply call `Ratchetio.report_exception`:

```ruby
begin
  foo = bar
rescue Exception => e
  Ratchetio.report_exception(e)
end
```

If you're reporting an exception in the context of a request and are in a controller, you can pass along the same request and person context as the global exception handler, like so:

```ruby
begin
  foo = bar
rescue Exception => e
  Ratchetio.report_exception(e, ratchetio_request_data, ratchetio_person_data)
end
```

You can also log individual messages:

```ruby
# logs at the 'warning' level. all levels: debug, info, warning, error, critical
Ratchetio.report_message("Unexpected input", "warning")

# default level is "info"
Ratchetio.report_message("Login successful")

# can also include additional data as a hash in the final param. :body is reserved.
Ratchetio.report_message("Login successful", "info", :user => @user)
```


## Person tracking

Ratchet will send information about the current user (called a "person" in Ratchet parlance) along with each error report, when available. This works by calling the `current_user` controller method. The return value should be an object with an `id` method and, optionally, `username` and `email` methods.

If the gem should call a controller method besides `current_user`, add the following in `config/initializers/ratchetio.rb`:

```ruby
  config.person_method = "my_current_user"
```

If the methods to extract the `id`, `username`, and `email` from the object returned by the `person_method` have other names, configure like so in `config/initializers/ratchetio.rb`:

```ruby
  config.person_id_method = "user_id"  # default is "id"
  config.person_username_method = "user_name"  # default is "username"
  config.person_email_method = "email_address"  # default is "email"
```


## Exception level filters

By default, all exceptions reported through `Ratchetio.report_exception()` are reported at the "error" level, except for the following, which are reported at "warning" level:

- ActiveRecord::RecordNotFound
- AbstractController::ActionNotFound
- ActionController::RoutingError

If you'd like to customize this list, see the example code in `config/initializers/ratchetio.rb`. Supported levels: "critical", "error", "warning", "info", "debug", "ignore". Set to "ignore" to cause the exception not to be reported at all.



## Asynchronous reporting

By default, all messages are reported synchronously. You can enable asynchronous reporting by adding the following in `config/initializers/ratchetio.rb`:

```ruby
  config.use_async = true
```

Ratchet uses [girl_friday](https://github.com/mperham/girl_friday) to handle asynchronous reporting when installed, and falls back to Threading if girl_friday is not installed.

You can supply your own handler using `config.async_handler`. The handler should schedule the payload for later processing (i.e. with a delayed_job, in a resque queue, etc.) and should itself return immediately. For example:

```ruby
  config.async_handler = Proc.new { |payload|
    Thread.new { Ratchetio.process_payload(payload) }
  }
```

Make sure you pass `payload` to `Ratchetio.process_payload` in your own implementation.


## Using with ratchet-agent

For even more asynchrony, you can configure the gem to write to a file instead of sending the payload to Ratchet servers directly. [ratchet-agent](https://github.com/ratchetio/ratchet-agent) can then be hooked up to this file to actually send the payload across. To enable, add the following in `config/initializers/ratchetio.rb`:

```ruby
  config.write_to_file = true
  # optional, defaults to "#{AppName}.ratchet"
  config.filepath = '/path/to/file.ratchet' #should end in '.ratchet' for use with ratchet-agent
```

For this to work, you'll also need to set up ratchet-agent--see its docs for details.


## Help / Support

If you run into any issues, please email us at `support@ratchet.io`

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

We're using RSpec for testing. Run the test suite with `rake spec`. Tests for pull requests are appreciated but not required. (If you don't include a test, we'll write one before merging.)
