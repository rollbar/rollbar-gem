# Rollbar notifier for Ruby [![Build Status](https://secure.travis-ci.org/rollbar/rollbar-gem.png?branch=master)](https://travis-ci.org/rollbar/rollbar-gem)

<!-- RemoveNext -->
Ruby gem for reporting exceptions, errors, and log messages to [Rollbar](https://rollbar.com).

<!-- Sub:[TOC] -->

## Installation

Add this line to your application's Gemfile:

    gem 'rollbar'

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install rollbar
```

Then, run the following command from your rails root:

```bash
$ rails generate rollbar POST_SERVER_ITEM_ACCESS_TOKEN
```

<!-- RemoveNextIfProject -->
Be sure to replace ```POST_SERVER_ITEM_ACCESS_TOKEN``` with your project's ```post_server_item``` access token, which you can find in the Rollbar.com interface.


That will create the file ```config/initializers/rollbar.rb```, which holds the configuration values (currently just your access token).

If you want to store your access token outside of your repo, run the same command without arguments:

```bash
$ rails generate rollbar
```

Then, create an environment variable ```ROLLBAR_ACCESS_TOKEN``` and set it to your server-side access token.

```bash
$ export ROLLBAR_ACCESS_TOKEN=POST_SERVER_ITEM_ACCESS_TOKEN
```

### For Heroku users

```bash
$ heroku config:add ROLLBAR_ACCESS_TOKEN=POST_SERVER_ITEM_ACCESS_TOKEN
```

That's all you need to use Rollbar with Rails.

## Test your installation

To confirm that it worked, run:

```bash
$ rake rollbar:test
```

This will raise an exception within a test request; if it works, you'll see a stacktrace in the console, and the exception will appear in the Rollbar dashboard.

## Reporting form validation errors

To get form validation errors automatically reported to Rollbar just add the following ```after_validation``` callback to your models:

```ruby
after_validation :report_validation_errors_to_rollbar
```

## Manually reporting exceptions and messages

To report a caught exception to Rollbar, simply call ```Rollbar.report_exception```:

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

## Data sanitization (scrubbing)

By default, the notifier will "scrub" the following fields from requests before sending to Rollbar

- ```:passwd```
- ```:password```
- ```:password_confirmation```
- ```:secret```
- ```:confirm_password```
- ```:password_confirmation```
- ```:secret_token```

If a request contains one of these fields, the value will be replaced with a ```"*"``` before being sent.

Additional fields can be scrubbed by updating ```Rollbar.configuration.scrub_fields```:

```ruby
# scrub out the "user_password" field
Rollbar.configuration.scrub_fields |= [:user_password]
```

## Person tracking

Rollbar will send information about the current user (called a "person" in Rollbar parlance) along with each error report, when available. This works by calling the ```current_user``` controller method. The return value should be an object with an ```id``` method and, optionally, ```username``` and ```email``` methods.

If the gem should call a controller method besides ```current_user```, add the following in ```config/initializers/rollbar.rb```:

```ruby
config.person_method = "my_current_user"
```

If the methods to extract the ```id```, ```username```, and ```email``` from the object returned by the ```person_method``` have other names, configure like so in ```config/initializers/rollbar.rb```:

```ruby
config.person_id_method = "user_id"  # default is "id"
config.person_username_method = "user_name"  # default is "username"
config.person_email_method = "email_address"  # default is "email"
```

### If using Rails and not ActiveRecord

By default, the `Rollbar::Middleware::Rails::RollbarRequestStore` middleware is inserted just before the `ActiveRecord::ConnectionAdapters::ConnectionManagement` middleware if `ActiveRecord` is defined. This middleware ensures that any database calls needed to grab person data are executed before connections are cleaned up in the `ConnectionManagement` middleware.

If you are not using `ActiveRecord`, make sure you include the `RollbarRequestStore` middleware before any middlewares that do similar connection clean up.

## Including additional runtime data

You can provide a lambda that will be called for each exception or message report.  ```custom_data_method``` should be a lambda that takes no arguments and returns a hash.

Add the following in ```config/initializers/rollbar.rb```:

```ruby
config.custom_data_method = lambda {
  { :some_key => :some_value, :complex_key => {:a => 1, :b => [2, 3, 4]} }
}
```

This data will appear in the Occurrences tab and on the Occurrence Detail pages in the Rollbar interface.

## Exception level filters

By default, all exceptions reported through ```Rollbar.report_exception()``` are reported at the "error" level, except for the following, which are reported at "warning" level:

- ```ActiveRecord::RecordNotFound```
- ```AbstractController::ActionNotFound```
- ```ActionController::RoutingError```

If you'd like to customize this list, see the example code in ```config/initializers/rollbar.rb```. Supported levels: "critical", "error", "warning", "info", "debug", "ignore". Set to "ignore" to cause the exception not to be reported at all.

## Silencing exceptions at runtime

If you just want to disable exception reporting for a single block, use ```Rollbar.silenced```:

```ruby
Rollbar.silenced {
  foo = bar  # will not be reported
}
```

## Asynchronous reporting

By default, all messages are reported synchronously. You can enable asynchronous reporting with [girl_friday](https://github.com/mperham/girl_friday) or [sucker_punch](https://github.com/brandonhilkert/sucker_punch) or [Sidekiq](https://github.com/mperham/sidekiq).

### Using girl_friday

Add the following in ```config/initializers/rollbar.rb```:

```ruby
config.use_async = true
```

Asynchronous reporting falls back to Threading if girl_friday is not installed.

### Using sucker_punch

Add the following in ```config/initializers/rollbar.rb```:

```ruby
config.use_sucker_punch
```

### Using Sidekiq

Add the following in ```config/initializers/rollbar.rb```:

```ruby
config.use_sidekiq
```

You can also supply custom Sidekiq options:

```ruby
config.use_sidekiq 'queue' => 'my_queue'
```

Start the redis server:

```bash
$ redis-server
```

Start Sidekiq from the root directory of your Rails app and declare the name of your queue. Unless you've configured otherwise, the queue name is "rollbar":

```bash
$ bundle exec sidekiq -q rollbar
```

### Using another handler

You can supply your own handler using ```config.async_handler```. The handler should schedule the payload for later processing (i.e. with a delayed_job, in a resque queue, etc.) and should itself return immediately. For example:

```ruby
config.async_handler = Proc.new { |payload|
  Thread.new { Rollbar.process_payload(payload) }
}
```

Make sure you pass ```payload``` to ```Rollbar.process_payload``` in your own implementation.

## Using with rollbar-agent

For even more asynchrony, you can configure the gem to write to a file instead of sending the payload to Rollbar servers directly. [rollbar-agent](https://github.com/rollbar/rollbar-agent) can then be hooked up to this file to actually send the payload across. To enable, add the following in ```config/initializers/rollbar.rb```:

```ruby
config.write_to_file = true
# optional, defaults to "#{AppName}.rollbar"
config.filepath = '/path/to/file.rollbar' #should end in '.rollbar' for use with rollbar-agent
```

For this to work, you'll also need to set up rollbar-agent--see its docs for details.

## Deploy Tracking with Capistrano

Add the following to ```deploy.rb```:

```ruby
require 'rollbar/capistrano'
set :rollbar_token, 'POST_SERVER_ITEM_ACCESS_TOKEN'
```

Available options:

  <dl>
  <dt>rollbar_token</dt>
  <dd>The same project access token as you used for the ```rails generate rollbar``` command; find it in ```config/initializers/rollbar.rb```. (It's repeated here for performance reasons, so the rails environment doesn't have to be initialized.)
  </dd>
  <dt>rollbar_env</dt>
  <dd>Deploy environment name

Default: ```rails_env```

  </dd>
  </dl>

For ```capistrano/multistage```, try:

```ruby
set(:rollbar_env) { stage }
```

## Counting specific gems as in-project code

In the Rollbar interface, stacktraces are shown with in-project code expanded and other code collapsed. Stack frames are counted as in-project if they occur in a file that is inside of the `configuration.root` (automatically set to ```Rails.root``` if you're using Rails). The collapsed sections can be expanded by clicking on them.

If you want code from some specific gems to start expanded as well, you can configure this in ```config/initializers/rollbar.rb```:

```ruby
Rollbar.configure do |config |
  config.access_token = '...'
  config.project_gems = ['my_custom_gem', 'my_other_gem']
end
```

## Using with Goalie

If you're using [Goalie](https://github.com/obvio171/goalie) for custom error pages, you may need to explicitly add ```require 'goalie'``` to ```config/application.rb``` (in addition to ```require 'goalie/rails'```) so that the monkeypatch will work. (This will be obvious if it is needed because your app won't start up: you'll see a cryptic error message about ```Goalie::CustomErrorPages.render_exception``` not being defined.)


## Using with Resque

Check out [resque-rollbar](https://github.com/CrowdFlower/resque-rollbar) for using Rollbar as a failure backend for Resque.


## Using with Zeus

Some users have reported problems with Zeus when ```rake``` was not explicitly included in their Gemfile. If the zeus server fails to start after installing the rollbar gem, try explicitly adding ```gem 'rake'``` to your ```Gemfile```. See [this thread](https://github.com/rollbar/rollbar-gem/issues/30) for more information.


## Help / Support

If you run into any issues, please email us at [support@rollbar.com](mailto:support@rollbar.com)

You can also find us in IRC: [#rollbar on chat.freenode.net](irc://chat.freenode.net/rollbar)

For bug reports, please [open an issue on GitHub](https://github.com/rollbar/rollbar-gem/issues/new).

## Contributing

1. Fork it
2. Create your feature branch (```git checkout -b my-new-feature```).
3. Commit your changes (```git commit -am 'Added some feature'```)
4. Push to the branch (```git push origin my-new-feature```)
5. Create new Pull Request

We're using RSpec for testing. Run the test suite with ```rake spec```. Tests for pull requests are appreciated but not required. (If you don't include a test, we'll write one before merging.)
