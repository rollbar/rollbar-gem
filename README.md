# Rollbar notifier for Ruby [![Build Status](https://api.travis-ci.org/rollbar/rollbar-gem.svg?branch=v1.5.0)](https://travis-ci.org/rollbar/rollbar-gem/branches)

<!-- RemoveNext -->
[Rollbar](https://rollbar.com) is an error tracking service for Ruby and other languages. The Rollbar service will alert you of problems with your code and help you understand them in a ways never possible before. We love it and we hope you will too.

This is the Ruby library for Rollbar. It will instrument many kinds of Ruby applications automatically at the framework level. You can also make direct calls to send exceptions and messages to Rollbar.

<!-- Sub:[TOC] -->

## Getting Started

Add this line to your application's Gemfile:

```ruby
gem 'rollbar', '~> 1.5.0'
```

And then execute:

```bash
$ bundle install
# Or if you don't use bundler:
$ gem install rollbar
```

### If using Rails

Run the following command from your Rails root:

```bash
$ rails generate rollbar POST_SERVER_ITEM_ACCESS_TOKEN
```

<!-- RemoveNextIfProject -->
Be sure to replace ```POST_SERVER_ITEM_ACCESS_TOKEN``` with your project's ```post_server_item``` access token, which you can find in the Rollbar.com interface.

That will create the file ```config/initializers/rollbar.rb```, which initializes Rollbar and holds your access token and other configuration values.

If you want to store your access token outside of your repo, run the same command without arguments and create an environment variable ```ROLLBAR_ACCESS_TOKEN``` that holds your server-side access token:

```bash
$ rails generate rollbar
$ export ROLLBAR_ACCESS_TOKEN=POST_SERVER_ITEM_ACCESS_TOKEN
```

For Heroku users:

If you're on Heroku, you can store the access token in your Heroku config:

```bash
$ heroku config:add ROLLBAR_ACCESS_TOKEN=POST_SERVER_ITEM_ACCESS_TOKEN
```

That's all you need to use Rollbar with Rails.


### If using Rack

Initialize Rollbar with your access token somewhere during startup:

```ruby
Rollbar.configure do |config|
  config.access_token = 'POST_SERVER_ITEM_ACCESS_TOKEN'
  # other configuration settings
  # ...
end
```

<!-- RemoveNextIfProject -->
Be sure to replace ```POST_SERVER_ITEM_ACCESS_TOKEN``` with your project's ```post_server_item``` access token, which you can find in the Rollbar.com interface.

This monkey patches `Rack::Builder` to work with Rollbar automatically.

For more control, disable the monkey patch:

```ruby
Rollbar.configure do |config|
  config.disable_monkey_patch = true
  # other configuration settings
  # ...
end
```

Then mount the middleware in your app, like:

```ruby
class MyApp < Sinatra::Base
  use Rollbar::Middleware::Sinatra
  # other middleware/etc
  # ...
end
```

## Test your installation

To confirm that it worked, run:

```bash
$ rake rollbar:test
```

This will raise an exception within a test request; if it works, you'll see a stacktrace in the console, and the exception will appear in the Rollbar dashboard.

## Usage

### Uncaught exceptions

Uncaught exceptions in Rails controllers will be automatically reported to Rollbar.

### Caught exceptions and messages

You can use one of `Rollbar.log(level, ...)`, `Rollbar.debug()`, `Rollbar.info()`, `Rollbar.warning()`, `Rollbar.error()` and `Rollbar.critical()` to report exceptions and messages.

The methods accept any number of arguments. The last exception is used as the reported exception, the last string is used as the message/description, and the last hash is used as the extra data.

For example:

```ruby
begin
  result = user_info[:key1][:key2][:key3]
rescue NoMethodError => e
  # simple exception report (level can be 'debug', 'info', 'warning', 'error' and 'critical')
  Rollbar.log('error', e)
  
  # same functionality as above
  Rollbar.error(e)
  
  # with a description
  Rollbar.error(e, 'The user info hash doesn\'t contain the correct data')
  
  # with extra data giving more insight about the exception
  Rollbar.error(e, :user_info => user_info, :job_id => job_id)
end
```

You can also log individual messages:

```ruby
Rollbar.warning('Unexpected input')

# can also include extra data
Rollbar.info("Login successful", :username => @username)

Rollbar.log('debug', 'Settings saved', :account_id => account.id)
```

### Reporting form validation errors

To get form validation errors automatically reported to Rollbar just add the following ```after_validation``` callback to your models:

```ruby
after_validation :report_validation_errors_to_rollbar
```

### Advanced usage

You can use `Rollbar.scope()` to copy a notifier instance and customize the payload data for one-off reporting. The hash argument to `scope()` will be merged into the copied notifier's "payload options", a hash that will be merged into the final payload just before it is reported to Rollbar. 

For example:

```ruby
while job
  user = job.user

  # Overwrites any existing person data
  notifier = Rollbar.scope({
    :person => {:id => user.id, :username => user.username, :email => user.email}
  })

  begin
    job.do_work
  rescue => e
    # Sends a report with the above person data
    notifier.critical(e)
  end

  job = next_job
end

# Wipe person data
notifier = notifier.scope({
  :person => nil
})

# No associated person data
notifier.info('Jobs processed')
```

If you don't want to work with a new `Notifier` instance `.scoped` will do it for you:

```ruby
while job
  user = job.user

  # Overwrites any existing person data
  scope = {
    :person => {:id => user.id, :username => user.username, :email => user.email}
  }

  Rollbar.scoped(scope) do
    begin
      job.do_work
    rescue => e
      # Sends a report with the above person data
      Rollbar.critical(e)
    end
  end

  job = next_job
end
```

To modify the current scope (rather than creating a new one), use `Rollbar.scope!`. You can use this to add additional context data from inside a web request, background job, etc.

```ruby
class NotificationJob
  include Sidekiq::Worker

  def perform(user_id)
    Rollbar.scope!(:person => { :id => :user_id })

    # If this next line causes an exception, the reported exception (which will
    # be reported by Rollbar's standard Sidekiq instrumentation) will also
    # include the above person information.
    Notification.send_to_user(user_id)
  end
end
```


## Person tracking

Rollbar will send information about the current user (called a "person" in Rollbar parlance) along with each error report, when available. This works by calling the ```current_user``` controller method. The return value should be an object with an ```id``` method and, optionally, ```username``` and ```email``` methods.

This will happen automatically for uncaught Rails exceptions and for any manual exception or log reporting done within a Rails request.

If the gem should call a controller method besides ```current_user```, add the following in ```config/initializers/rollbar.rb```:

```ruby
Rollbar.configure do |config|
  config.person_method = "my_current_user"
end
```

If the methods to extract the ```id```, ```username```, and ```email``` from the object returned by the ```person_method``` have other names, configure like so in ```config/initializers/rollbar.rb```:

```ruby
Rollbar.configure do |config|
  config.person_id_method = "user_id"  # default is "id"
  config.person_username_method = "user_name"  # default is "username"
  config.person_email_method = "email_address"  # default is "email"
end
```

### Person tracking with Rack applications

To track information about the current user in non-Rails applications, you can populate the `rollbar.person_data` key in the Rack environment with the desired data. Its value should be a hash like:

```ruby
{
  :id => "123",  # required; string up to 40 characters
  :username => "adalovelace",  # optional; string up to 255 characters
  :email => "ada@lovelace.net"  # optional; string up to 255 characters
}
```

Because Rack applications can vary so widely, we don't provide a default implementation in the gem, but here is an example middleware:

```ruby
class RollbarPersonData
  def initialize(app)
    @app = app
  end

  def call(env)
    token = Rack::Request.new(env).params['token']
    user = User.find_by_token(token)

    if user
      env['rollbar.person_data'] = extract_person_data(user)
    end

    @app.call(env)
  end

  def extract_person_data(user)
    {
      id: user.id,
      username: user.username,
      email: user.email
    }
  end
end

# You can add the middleware to your application, for example:

class App < Sinatra::Base
  use Rollbar::Middleware::Sinatra
  use RollbarPersonData

  # ...
  # ...
end
```

## Special note about reporting within a request

The gem instantiates one `Notifier` instance on initialization, which will be the base notifier that is used for all reporting (via a `method_missing` proxy in the `Rollbar` module). Calling `Rollbar.configure()` will configure this base notifier that will be used globally in a ruby app.

However, the Rails middleware will actually scope this base notifier for use within a request by storing it in thread-local storage (see [here](https://github.com/rollbar/rollbar-gem/blob/5f4e6135f0e61148672b0190c88767aa52e5cdb3/lib/rollbar/middleware/rails/rollbar.rb#L35-L39)). This is done to make any manual logging within a request automatically contain request and person data. Calling `Rollbar.configure()` therefore will only affect the notifier for the duration of the request, and not the base notifier used globally.

## Data sanitization (scrubbing)

By default, the notifier will "scrub" the following fields from payloads before sending to Rollbar

- ```:passwd```
- ```:password```
- ```:password_confirmation```
- ```:secret```
- ```:confirm_password```
- ```:password_confirmation```
- ```:secret_token```

And the following http header

- ```"Authorization"```

If a request contains one of these fields, the value will be replaced with a ```"*"``` before being sent.

Additional fields can be scrubbed by updating ```Rollbar.configuration.scrub_fields```:

```ruby
# scrub out the "user_password" field
Rollbar.configuration.scrub_fields |= [:user_password]
```

And ```Rollbar.configuration.scrub_headers```:

```ruby
# scrub out the "X-Access-Token" http header
Rollbar.configuration.scrub_headers |= ["X-Access-Token"]
```

## Including additional runtime data

You can provide a callable that will be called for each exception or message report.  ```custom_data_method``` should be a lambda that takes no arguments and returns a hash.

Add the following in ```config/initializers/rollbar.rb```:

```ruby
config.custom_data_method = lambda {
  { :some_key => :some_value, :complex_key => {:a => 1, :b => [2, 3, 4]} }
}
```

This data will appear in the Occurrences tab and on the Occurrence Detail pages in the Rollbar interface.

If your `custom_data_method` crashes while reporting an error, Rollbar will report that new error and will attach its uuid URL to the parent error report.

## Exception level filters

By default, all uncaught exceptions are reported at the "error" level, except for the following, which are reported at "warning" level:

- ```ActiveRecord::RecordNotFound```
- ```AbstractController::ActionNotFound```
- ```ActionController::RoutingError```

If you'd like to customize this list, see the example code in ```config/initializers/rollbar.rb```. Supported levels: "critical", "error", "warning", "info", "debug", "ignore". Set to "ignore" to cause the exception not to be reported at all.

This behavior applies to uncaught exceptions, not direct calls to `Rollbar.error()`, `Rollbar.warning()`, etc. If you are making a direct call to one of the log methods and want exception level filters to apply, pass an extra keyword argument:

```ruby
Rollbar.error(exception, :use_exception_level_filters => true)
```

## Silencing exceptions at runtime

If you just want to disable exception reporting for a single block, use ```Rollbar.silenced```:

```ruby
Rollbar.silenced {
  foo = bar  # will not be reported
}
```

# Sending backtrace without rescued exceptions

If you use the gem in this way:

```ruby
exception = MyException.new('this is a message')
Rollbar.error(exception)
```

You will notice a backtrace doesn't appear in your Rollbar dashboard. This is because `exception.backtrace` is `nil` in these cases. We can send the current backtrace for you even your exception doesn't have it. In order to enable this feature you should configure Rollbar in this way:

```ruby
Rollbar.configure do |config|
  config.populate_empty_backtraces = true
end
```

## Delayed::Job integration

If `delayed_job` is defined, Rollbar will automatically install a plugin that reports any uncaught exceptions that occur in jobs.

By default, the job's data will be included in the report. If you want to disable this functionality to prevent sensitive data from possibly being sent, use the following configuration option:

```ruby
config.report_dj_data = false # default is true
```

You can also change the threshold of job retries that must occur before a job is reported to Rollbar:

```ruby
config.dj_threshold = 2 # default is 0
```

If you use [custom jobs](https://github.com/collectiveidea/delayed_job#custom-jobs) that define their own hooks to report exceptions, please consider disabling our plugin. Not doing so will result in duplicate exceptions being reported as well as lack of control when exceptions should be reported. To disable our Delayed::Job plugin, add the following line after the `Rollbar.configure` block.

```ruby
config.delayed_job_enabled = false
```


## Asynchronous reporting

By default, all messages are reported synchronously. You can enable asynchronous reporting with [girl_friday](https://github.com/mperham/girl_friday), [sucker_punch](https://github.com/brandonhilkert/sucker_punch), [Sidekiq](https://github.com/mperham/sidekiq), [Resque](https://github.com/resque/resque) or using threading.

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

### Using Resque

Add the following in ```config/initializers/rollbar.rb```:

```ruby
config.use_resque
```

You can also supply a custom Resque queue:

```ruby
config.use_resque :queue => 'my_queue'
```

Now you can just start a new Resque worker processing jobs in that queue:

```bash
$ QUEUE=my_queue bundle exec resque:work
```

### Using threading

Add the following in ```config/initializers/rollbar.rb```:

```ruby
config.use_thread
```

### Using another handler

You can supply your own handler using ```config.async_handler```. The object to set for `async_handler` should respond to `#call` and receive the payload. The handler should schedule the payload for later processing (i.e. with a delayed_job, in a resque queue, etc.) and should itself return immediately. For example:

```ruby
config.use_async
config.async_handler = Proc.new { |payload|
  Thread.new { Rollbar.process_payload_safely(payload) }
}
```

Make sure you pass ```payload``` to ```Rollbar.process_payload_safely``` in your own implementation.

## Failover handlers

If you are using `async_handler` to process asynchronous the error it's possible that the handler fails before it calls `Rollbar.process_payload`. For example, for the Resque handler, the Redis connection could fail so the job is finally not processed.

To ensure that the error is sent you can define a chain of failover handlers that Rollbar will use to send the payload in case that the primary handler fails. The failover handlers, as for `async_handler`, are just objects responding to `#call`.

To configure the failover handlers you can add the following:

```ruby
config.use_resque
config.failover_handlers = [Rollbar::Delay::GirlFriday, Rollbar::Delay::Thread]
```

With the configuration above Resque will be your primary asynchronous handler but if it fails queueing the job Rollbar will use GirlFriday at first, and just a thread in case that GirlFriday fails too.

## Using with rollbar-agent

For even more asynchrony, you can configure the gem to write to a file instead of sending the payload to Rollbar servers directly. [rollbar-agent](https://github.com/rollbar/rollbar-agent) can then be hooked up to this file to actually send the payload across. To enable, add the following in ```config/initializers/rollbar.rb```:

```ruby
config.write_to_file = true
# optional, defaults to "#{AppName}.rollbar"
config.filepath = '/path/to/file.rollbar' #should end in '.rollbar' for use with rollbar-agent
```

For this to work, you'll also need to set up rollbar-agent--see its docs for details.

## Rails booting process

Rails doesn't provide a way to hook into its booting process, so we can't catch errors during boot out of the box. To report these errors to Rollbar, make the following changes to your project files.

First, move your `config/initializers/rollbar.rb` file to `config/rollbar.rb`. Then be sure your `config/environment.rb` looks similar to this:

```ruby
# config/environment.rb

require File.expand_path('../application', __FILE__)
require File.expand_path('../rollbar', __FILE__)

begin
  Rails.application.initialize!
rescue Exception => e
  Rollbar.error(e)
  raise
end
```

How this works: first, Rollbar config (which is now at `config/rollbar.rb` is required). Later, `Rails.application/initialize` statement is wrapped with a `begin/rescue` and any exceptions within will be reported to Rollbar.

## Rails runner command

We aren't able to instrument `rails runner` directly, but we do provide a wrapper, `rollbar-rails-runner`, which you can use to capture errors when running commands in a `rails runner`-like way. For example:

```shell
$ bundle exec rollbar-rails-runner 'puts User.count'
45
```

If an error occurs during that command, the exception will be reported to Rollbar.

## Deploy Tracking with Capistrano

### Capistrano 3

Add to your `Capfile`:

```ruby
require 'rollbar/capistrano3'
```

And then, to your `deploy.rb`:

```ruby
set :rollbar_token, 'POST_SERVER_ITEM_ACCESS_TOKEN'
set :rollbar_env, Proc.new { fetch :stage }
set :rollbar_role, Proc.new { :app }
```

### Capistrano 2

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

Check out [resque-rollbar](https://github.com/dimko/resque-rollbar) for using Rollbar as a failure backend for Resque.


## Using with Zeus

Some users have reported problems with Zeus when ```rake``` was not explicitly included in their Gemfile. If the zeus server fails to start after installing the rollbar gem, try explicitly adding ```gem 'rake'``` to your ```Gemfile```. See [this thread](https://github.com/rollbar/rollbar-gem/issues/30) for more information.

## Backwards Compatibility

You can find upgrading notes in [UPGRADING.md](UPGRADING.md).

## Known Issues

We've received some issues from users having problems when they use [Oj](https://github.com/ohler55/oj) as the JSON serialization library with [MultiJson](https://github.com/intridea/multi_json). To avoid these problems, we recommend upgrading to Oj version 2.11.0:

```ruby
gem 'oj', '~> 2.11.0'
```

If you are using Oj but cannot upgrade, you can work around this with:

```ruby
require 'json'
MultiJson.use(:json_common)
```


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
