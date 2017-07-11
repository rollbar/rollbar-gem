# Rollbar [![Build Status](https://api.travis-ci.org/rollbar/rollbar-gem.svg?branch=v2.15.0)](https://travis-ci.org/rollbar/rollbar-gem/branches)

<!-- RemoveNext -->
[Rollbar](https://rollbar.com) is an error tracking service for Ruby and other languages. The Rollbar service will alert you of problems with your code and help you understand them in a ways never possible before. We love it and we hope you will too.

This is the Ruby library for Rollbar. It will instrument many kinds of Ruby applications automatically at the framework level. You can also make direct calls to send exceptions and messages to Rollbar.

<!-- Sub:[TOC] -->

## Getting Started

Add this line to your application's Gemfile:

```ruby
gem 'rollbar'
```

And then execute:

```bash
$ bundle install
# Or if you don't use bundler:
$ gem install rollbar
```

Unless you are using JRuby, we suggest also installing [Oj](https://github.com/ohler55/oj) for JSON serialization. Add this line to your Gemfile:

```ruby
gem 'oj', '~> 2.12.14'
```

and then `bundle install` again.

### Rails

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


### Sinatra

Initialize Rollbar with your access token somewhere during startup:

```ruby
Rollbar.configure do |config|
  config.access_token = 'POST_SERVER_ITEM_ACCESS_TOKEN'
  # other configuration settings
  # ...
end
```

Then mount the middleware in your app, like:

```ruby
require 'rollbar/middleware/sinatra'

class MyApp < Sinatra::Base
  use Rollbar::Middleware::Sinatra
  # other middleware/etc
  # ...
end
```


### Rack

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

The gem monkey patches `Rack::Builder` so Rollbar reports will be sent automatically without any other action. If you prefer to disable the monkey patch apply this change to your config:

```ruby
Rollbar.configure do |config|
  config.disable_rack_monkey_patch = true
  # other configuration settings
  # ...
end
```

If you disabled the `Rack::Builder` monkey patch or it doesn't work for the Rack framework you are using, then add our Rack middleware to your app:

```ruby
require 'rollbar/middleware/rack'

use Rollbar::Middleware::Rack
```

### Plain Ruby

Rollbar isn't dependent on Rack or Rails for most of its functionality. In a regular script, assuming you've
installed the rollbar gem:

 1. Require rollbar
 2. Configure rollbar
 3. Send Rollbar data

```ruby
require 'rollbar'

Rollbar.configure do |config|
  config.access_token = "POST_SERVER_ITEM_ACCESS_TOKEN"
  # Other Configuration Settings
end

Rollbar.debug("Running Script")

begin
  run_script ARGV
rescue Exception => e # Never rescue Exception *unless* you re-raise in rescue body
  Rollbar.error(e)
  raise e
end

Rollbar.info("Script ran successfully")
```


## Integration with Rollbar.js

In case you want to report your JavaScript errors using [Rollbar.js](https://github.com/rollbar/rollbar.js), you can configure the gem to enable Rollbar.js on your site. Example:

```ruby
Rollbar.configure do |config|
  # common gem configuration
  # ...
  config.js_enabled = true
  config.js_options = {
    accessToken: "POST_CLIENT_ITEM_ACCESS_TOKEN",
    captureUncaught: true,
    payload: {
      environment: "production"
    }
  }
end
```

The `Hash` passed to `#js_options=` should have the same available options that you can find in [Rollbar.js](https://github.com/rollbar/rollbar.js), using symbols or strings for the keys.

## Test your installation

If you're not using Rails, you may first need to add the following to your Rakefile:

```ruby
require 'rollbar/rake_tasks'
```

You may also need to add an `:environment` task to your Rakefile if you haven't already defined one. At a bare minimum, this task should call `Rollbar.configure()` and set your access token.

```ruby
task :environment do
  Rollbar.configure do |config |
    config.access_token = '...'
  end
end
```

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
    Rollbar.scope!(:person => { :id => user_id })

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

require 'rollbar/middleware/sinatra'

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
- ```:secret_token```

And the following http header

- ```"Authorization"```

If a request contains one of these fields, the value will be replaced with a ```"*"``` before being sent.

Additional params can be scrubbed by updating ```config.scrub_fields```:

```ruby
# scrub out the "user_password" field
config.scrub_fields |= [:user_password]
```

And ```config.scrub_headers```:

```ruby
# scrub out the "X-Access-Token" http header
config.scrub_headers |= ["X-Access-Token"]
```

If you want to obfuscate the user IP reported to the Rollbar API you can configure a secret to do it and a different IP address from the original will be reported:

```
Rollbar.configuration.user_ip_obfuscator_secret = "a-private-secret-here"
```

The fields in `scrub_fields` will be used to scrub the values for the matching keys in the GET, POST, raw body and route params and also in cookies and session. If you want to customize better exactly which part of the request data is scrubbed you can use the [Transform hook](#transform-hook).

Example:

```
config.transform << proc do |options|
  data = options[:payload]['data']
  data[:request][:session][:key] = Rollbar::Scrubbers.scrub_value(data[:request][:session][:key])
end
```

In the previous example we are scrubbing the `key` value inside the session data.

If you would simply like to scrub all params, you can use `:scrub_all` like so:

```
config.scrub_fields = :scrub_all
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

If you'd like to customize this list, modify the example code in ```config/initializers/rollbar.rb```. Supported levels: "critical", "error", "warning", "info", "debug", "ignore". Set to "ignore" to cause the exception not to be reported at all. For example, to ignore 404s and treat `NoMethodError`s as critical bugs, you can use the following code:

```ruby
config.exception_level_filters.merge!({
  'ActionController::RoutingError' => 'ignore',
  'NoMethodError' => 'critical'
})
```

This behavior applies to uncaught exceptions, not direct calls to `Rollbar.error()`, `Rollbar.warning()`, etc. If you are making a direct call to one of the log methods and want exception level filters to apply, pass an extra keyword argument:

```ruby
Rollbar.error(exception, :use_exception_level_filters => true)
```

### Dynamic levels

You can also specify a callable object (any object that responds to `call`) which will be called with the exception instance. For example, you can have a single error reported at different levels using the following code:

```ruby
config.exception_level_filters.merge!({
  'SomeError' => lambda { |error| error.to_s.include?('not serious enough') ? 'info' : 'error' }
})
```

## Before process hook

Before we process data sent to Rollbar.log (or Rollbar.error/info/etc.) to build and send the payload, the gem will call the handlers defined in `configuration.before_process`. This handlers should be `Proc` objects or objects responding to `#call` method. The received argument is a `Hash` object with these keys:

- `level`: the level used for the report.
- `exception`: the exception that caused the report, if any.
- `message`: the message to use for the report, if any.
- `extra`: extra data passed to the report methods.
- `scope`: the current Scope; see [Scope](#the-scope)

If the exception `Rollbar::Ignore` is raised inside any of the handlers defined for `configuration.before_process`, we'll ignore the report and not send it to the API. For example:

```ruby
handler = proc do |options|
  raise Rollbar::Ignore if any_smart_method(options)
end

Rollbar.configure do |config|
  config.before_process << handler
end
```

## Transform hook

After the payload is built but before it it sent to our API, the gem will call the handlers defined in `configuration.transform`. This handlers should be `Proc` objects or objects responding to `#call` method. The received argument is a `Hash` object with these keys:

- `level`: the level used for the report.
- `exception`: the exception that caused the report, if any.
- `message`: the message to use for the report, if any.
- `extra`: extra data passed to the report methods.
- `scope`: the current Scope; see [Scope](#the-scope)
- `payload`: the built payload that will be sent to the API

Handlers may mutate the payload. For example:

```ruby
handler = proc do |options|
  payload = options[:payload]

  payload['data']['environment'] = 'foo'
end

Rollbar.configure do |config|
  config.transform << handler
end
```

## The Scope

The scope an object, an instance of `Rollbar::LazyStore` that stores the current context data for a certain moment or situation. For example, the Rails middleware defines the scope in a way similar to this:

```ruby
scope = {request: request_data,
         person: person_data,
         context: context_data
}
Rollbar.scoped(scope) do
  begin
    @app.call(env)
  rescue Exception => exception
    # ...
  end
end

```

You can access the scope on the [before_process](#before-process-hook) and [transform](#transform-hook) hooks like this:

```ruby
your_handler = proc do |options|
  scope = options[:scope]

  request_data = scope[:request]
  person_data = scope[:person]
  context_data = scope[:context]
end
```

## Override configuration

There are some cases where you would need to change the Rollbar configuration for a specific block of code so a new configuration is used on the reported errors in that block. You can use `Rollbar.with_config` to do this. It receives a `Hash` object with the configuration overrides you want to use for the given block. The configuration options to use can be read at [Configuration](https://rollbar.com/docs/notifier/rollbar-gem/configuration/). So the `Hash` passed to `with_config` can be like `{environment: 'specific-environment'}`. Example:

```ruby
Rollbar.with_config(use_async: false) do
  begin
    # do work that may crash
  rescue => e
    Rollbar.error(e)
  end
end
```

This method looks similar to `Rollbar.scoped` and internally `Rollbar.with_config` uses it. Now `Rollbar.scoped` can receive a second argument with the config overrides for the given block of code. So if you need to set a new payload scope and new config for a code block, you can:

```ruby
scope = {context: 'foo'}
new_config = {framework: 'Sinatra'}

Rollbar.scoped(scope, new_config) do
  begin
    # do work that may crash
  rescue => e
    Rollbar.error(e)
  end
end
```

In the example from above we are defining a new payload scope and overriding the `framework` configuration for the reported errors inside the given block.

## Code and context

By default we send the following values for each backtrace frame: `filename`, `lineno` and `method`. You can configure Rollbar to additionally send `code` (the actual line of code) and `context` (lines before and after) for each frame.

Since the backtrace can be very long, you can configure to send this data for all the frames or only your in-project frames. There are three levels: `:none` (default), `:app` (only your project files) and `:all`. Example:

```ruby
Rollbar.configure do |config|
   config.send_extra_frame_data = :app
end
```

## Silencing exceptions at runtime

If you just want to disable exception reporting for a single block, use ```Rollbar.silenced```:

```ruby
Rollbar.silenced {
  foo = bar  # will not be reported
}
```

## Sending backtrace without rescued exceptions

If you use the gem in this way:

```ruby
exception = MyException.new('this is a message')
Rollbar.error(exception)
```

You will notice a backtrace doesn't appear in your Rollbar dashboard. This is because `exception.backtrace` is `nil` in these cases. We can send the current backtrace for you even if your exception doesn't have it. In order to enable this feature you should configure Rollbar in this way:

```ruby
Rollbar.configure do |config|
  config.populate_empty_backtraces = true
end
```

## ActiveJob integration

Include the module `Rollbar::ActiveJob` in you jobs to report any uncaught errors in a job to Rollbar.

```ruby
class YourAwesomeJob < ActiveJob::Base
  include Rollbar::ActiveJob
end
```

If you need to customize the reporting write your own `rescue_from` handler instead of using the `Rollbar::ActiveJob` module.

Note: If you're using Sidekiq and integrate ActiveJob, you may get double reports of background job errors in Rollbar. The way to avoid this is to rely on the Sidekiq error handling, not ActiveJob in this case.

## Delayed::Job

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

Only versions >= 3.0 of delayed_job are supported.


## Asynchronous reporting

By default, all messages are reported synchronously. You can enable asynchronous reporting with [girl_friday](https://github.com/mperham/girl_friday), [sucker_punch](https://github.com/brandonhilkert/sucker_punch), [Sidekiq](https://github.com/mperham/sidekiq), [Resque](https://github.com/resque/resque), [DelayedJob](https://github.com/collectiveidea/delayed_job) or using threading.

### girl_friday

Add the following in ```config/initializers/rollbar.rb```:

```ruby
config.use_async = true
```

Asynchronous reporting falls back to Threading if girl_friday is not installed.

### sucker_punch

Add the following in ```config/initializers/rollbar.rb```:

```ruby
config.use_sucker_punch
```

### Sidekiq

Add the following in ```config/initializers/rollbar.rb```:

```ruby
config.use_sidekiq
```


The default Sidekiq queue will be `rollbar` but you can also supply custom Sidekiq options:

```ruby
config.use_sidekiq 'queue' => 'default'
```

You also need to add the name of the queue to your `sidekiq.yml`

```
:queues:
- default
- rollbar
```

Start the redis server:

```bash
$ redis-server
```

Start Sidekiq from the root directory of your Rails app and declare the name of your queue. Unless you've configured otherwise, the queue name is "rollbar":

```bash
$ bundle exec sidekiq -q rollbar
```

For every errored job a new report will be sent to Rollbar API, also for errored retried jobs. You can configure the retries threshold to start reporting to rollbar:

```ruby
config.sidekiq_threshold = 3 # Start reporting from 3 retries jobs
```

### Shoryuken

Add the following in ```config/initializers/rollbar.rb```

```ruby
config.environment = Rails.env # necessary for building proper SQS name.
config.use_shoryuken
```

You also need to have the configuration for shoryuken in you project `shoryuken.yml` and AWS settings, or, at least:
```ruby
ENV['AWS_ACCESS_KEY_ID'] = 'xxx'
ENV['AWS_SECRET_ACCESS_KEY'] = 'xxx'
ENV['AWS_REGION'] = 'xxx'
```
Read more about [Shoryuken configuration]https://github.com/phstc/shoryuken/wiki/Shoryuken-options

Also create the SQS channels equals to your environments, as follows:
The queues to report will be equal to ```rollbar_{CURRENT_ENVIRONMENT}``` ex: if the project runs in staging environment the SQS to throw messages to will be equal to ```rollbar_staging```
At this stage, you are unable to set custom SQS name to use.

### Resque

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

### DelayedJob

Add the following in ```config/initializers/rollbar.rb```:

```ruby
config.use_delayed_job
```

By default, an unnamed queue is used for processing jobs. If you wish to use a named queue, as
[described here](https://github.com/collectiveidea/delayed_job#named-queues), pass the name of the
queue as an option in the configuraton:

```ruby
config.use_delayed_job :queue => 'my_queue'
```


### Threading

Add the following in ```config/initializers/rollbar.rb```:

```ruby
config.use_thread
```

### Other handlers

You can supply your own handler using ```config.async_handler```. The object to set for `async_handler` should respond to `#call` and receive the payload. The handler should schedule the payload for later processing (i.e. with a delayed_job, in a resque queue, etc.) and should itself return immediately. For example:

```ruby
config.use_async = true
config.async_handler = Proc.new { |payload|
  Thread.new { Rollbar.process_from_async_handler(payload) }
}
```

Make sure you pass ```payload``` to ```Rollbar.process_from_async_handler``` in your own implementation.

### Failover handlers

If you are using `async_handler` to process asynchronous the error it's possible that the handler fails before it calls `Rollbar.process_payload`. For example, for the Resque handler, the Redis connection could fail so the job is finally not processed.

To ensure that the error is sent you can define a chain of failover handlers that Rollbar will use to send the payload in case that the primary handler fails. The failover handlers, as for `async_handler`, are just objects responding to `#call`.

To configure the failover handlers you can add the following:

```ruby
config.use_resque
config.failover_handlers = [Rollbar::Delay::GirlFriday, Rollbar::Delay::Thread]
```

With the configuration above Resque will be your primary asynchronous handler but if it fails queueing the job Rollbar will use GirlFriday at first, and just a thread in case that GirlFriday fails too.

## Logger interface

The gem provides a class `Rollbar::Logger` that inherits from `Logger` so you can use Rollbar to log your application messages. The basic usage is:

```ruby
require 'rollbar/logger'

logger = Rollbar::Logger.new
logger.info('Purchase failed!')
```

If you are using Rails you can extend your `Rails.logger` so the log messages are sent to both outputs. You can use this snippet in one initializer (for example, `config/initializers/rollbar.rb`):

```ruby
require 'rollbar/logger'

Rails.logger.extend(ActiveSupport::Logger.broadcast(Rollbar::Logger.new))
```

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

NOTE: We've seen problems with Capistrano version `3.0.x` where the revision reported is incorrect. Version `3.1.0` and higher works correctly.

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

## Goalie

If you're using [Goalie](https://github.com/obvio171/goalie) for custom error pages, you may need to explicitly add ```require 'goalie'``` to ```config/application.rb``` (in addition to ```require 'goalie/rails'```) so that the monkeypatch will work. (This will be obvious if it is needed because your app won't start up: you'll see a cryptic error message about ```Goalie::CustomErrorPages.render_exception``` not being defined.)


## Resque

From a time ago, Resque errors reporting was supported by the gem [resque-rollbar](https://github.com/dimko/resque-rollbar). Now that functionality is built-in in the own gem. All you need to do is use `Resque::Failure::Rollbar` as the failure backend for Resque.

In your resque configuration add next lines:

```ruby
require 'resque/failure/multiple'
require 'resque/failure/redis'
require 'rollbar'

Resque::Failure::Multiple.classes = [ Resque::Failure::Redis, Resque::Failure::Rollbar ]
Resque::Failure.backend = Resque::Failure::Multiple
```

## SSL

By default we use `OpenSSL::SSL::VERIFY_PEER` for SSL very mode. Although we don't recommend change it, you can disable peer verification in case you experience SSL connection problems:

```ruby
Rollbar.configure do |config|
  config.verify_ssl_peer = false
end
```


## Using with Zeus

Some users have reported problems with Zeus when ```rake``` was not explicitly included in their Gemfile. If the zeus server fails to start after installing the rollbar gem, try explicitly adding ```gem 'rake'``` to your ```Gemfile```. See [this thread](https://github.com/rollbar/rollbar-gem/issues/30) for more information.


## Configuration options

For a listing of all configuration options available, see
[configuration](https://rollbar.com/docs/notifier/rollbar-gem/configuration).

## Plugins

The support for the different frameworks and libraries is organized into different plugin definitions. The plugins architecture documentation can be found in [Plugins](https://rollbar.com/docs/notifier/rollbar-gem/plugins).

## Backwards Compatibility

You can find upgrading notes in [UPGRADING.md](UPGRADING.md).

## Known Issues

If you are using jRuby with Oracle and JDK7, you may be expecting some errors sending reports to our API. This is caused by a bug in that JDK and the primer number used in the SSL algorithm. In order to fix this you can set the next configuration:

```ruby
Rollbar.configure do|config|
  config.endpoint = 'https://api-alt.rollbar.com/api/1/item/'
end
```

## Supported Language/Framework Versions

We support Ruby >= 1.8.7.

We support Rails >= 3.0.

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
