# Configuration Reference

<!-- Sub:[TOC] -->

## General Settings

### access_token

**Required**

Sets the access token used to send payloads to rollbar.

Items sent through a given access token arrive in that access token's project
and respect the rate limits set on that access token.

### async_handler

If `config.use_async = true` explicitly sets the function used to send
asynchronous payloads to Rollbar. Should be an object that responds to `#call``
Not needed if using one of the built in async reporters:

 * girl_friday
 * sucker_punch
 * Sidekiq
 * Resque
 * threading

### branch

Name of the checked-out source control branch.

### code_version

A string, up to 40 characters, describing the version of the application code.

Rollbar understands these formats:

 * semantic version (i.e. "2.1.12")
 * integer (i.e. "45")
 * git SHA (i.e. "3da541559918a808c2402bba5012f6c60b27661c")

### custom_data_method

The method to call to gather custom data to send with each rollbar request.

```ruby
def custom_data
  return {
    :custom => {
      :key1 => get_key_one,
      :key2 => get_key_two
    },
    :server => {
      :root => '/home/username/www/'
    }
  }
end
```

### default_logger

**Default** `Logger.new(STDERR)`

What logger to use for printing debugging and informational messages during
operation.

### logger_level

**Default** `:info`

Regardless of what Logger you're using, Rollbar will not proxy logs to it if its less than this particular level.

### disable_monkey_patch

**Default** `false`

Disables monkey patching all non-core monkey patches and automatic reporting.

If you set this to true you will be responsible for rescuing and reporting all
errors manually.

### disable_core_monkey_patch

**Default** `false`

Disables our monkey patches in the ruby core. One mandatory monkey patch is left.
Be careful using this option as it may caused unexpected behavior in some situations.


### disable_rack_monkey_patch

**Default** `false`

Disables monkey patches on Rack classes, `Rack::Builder` for now, maybe more
at some point.

### delayed_job_enabled

**Default** `true`


Set to false if you have `delayed_job`  but do not wish to wrap jobs with a
Rollbar notifier.

### dj_threshold

**Default** 0 (Report *any* errors)

The number of job failures before reporting the failure to Rollbar.

### async_skip_report_handler

**Default** `nil`
**Example** `-> (job) { job.cron? }`

A handler, should respond to `#call`, receives the job and returns a boolean. If true, reporting errors will be skipped. If provided, dj_threshold isn't checked.

### enabled

**Default** `true`

Set to false to turn Rollbar off and stop reporting errors.

### environment

**Default** unspecified

The environment that your code is running in.

### failover_handlers

An array of backup handlers if the async handlers fails. Each should respond to
`#call` and should receive a `payload`.

### filepath

For use with `write_to_file`. Indicates location of the rollbar log file being
tracked by [rollbar-agent](https://github.com/rollbar/rollbar-agent).
Enable `files_with_pid_name_enabled` if you want to have different files for each process(only works if extension `rollbar`)

### framework

**Default** 'Plain'

Indicates which framework you're using. Common options include 'Rails',
'Sinatra', and 'Rack' to name a few.

### host

**Default** `nil`

The hostname (reported to Rollbar as `server.host`). When nil, the value of `Socket.gethostname` will be used.

### ignored_person_ids

**Default** `[]`

Ids of people whose reports you wish to ignore. Only works in conjunction with a
properly defined `person_method` or `person_id_method`.

### logger

The logger to use *instead of* the default logger. Especially useful when you
wish to send log messages elsewhere.

### payload_options

Extra data to send with the payload.

### person_method

Rails only: A string or symbol giving the name of the method on the controller.
Should return an object with an `id` method, and optionally `username` and
`email` methods. The names of the `id`, `username` and `email` methods can be
overridden. See `person_id_method`, `person_username_method`, and
`person_email_method`.

If not using Rails:

Populate the `rollbar.person_data` key with a hash containing `:id`, and
optionally `:username` and `:email`.

### person_id_method

A string or symbol giving the name of the method on the user instance that
returns the person's id. Gets called on the result of `person_method`. Ignored
if `person_method` not present.

### person_username_method

**Default** `nil`

A string or symbol giving the name of the method on the user instance that
returns the person's username. Gets called on the result of `person_method`.
Ignored if `person_method` not present.

### person_email_method

**Default** `nil`

A string or symbol giving the name of the method on the user instance that
returns the person's email. Gets called on the result of `person_method`.
Ignored if `person_method` not present.

### populate_empty_backtraces

Raising an exception in Ruby is what populates the backtraces. If you report a
manually initialized exception instead of a raised and rescued exception, the
backtraces will be empty. Set `populate_empty_backtraces` to `true` to have
Rollbar load the traces before sending them.

### report_dj_data

**Default** `true`

Set to `false` to skip automatic bundling of job metadata like queue, job class
name, and job options.

### open_timeout

**Default** `3`

### request_timeout

**Default** `3`

Set the request timeout for sending POST data to Rollbar.

### net_retries

**Default** `3`

Sets the number of retries cause timeouts on the POST request.

### root

Set the server root, all stack frames outside that root are considered
'non-project' frames. Also used to setup GitHub linking.

### safely

**Default** `false`

When `true` evaluates `custom_data_method` returns `{}` if an error,
otherwise reports the error to Rollbar.

### scrub_fields

Fields to scrub out of the parsed request data. Will scrub from `GET`, `POST`,
url, and several other locations. Does not currently recurse into the full
payload.

If set to `[:scrub_all]` it will scrub all fields. It will not scrub anything
that is in the scrub_whitelist configuration array even if :scrub_all is true.

### scrub_whitelist

Set the list of fields to be whitelisted when `scrub_fields` is set to `[:scrub_all]`.

Supports regex entries for partial matching e.g. `[:foo, /\A.+_id\z/, :bar]`

### scrub_user

**Default** `true`

Set to false to skip scrubbing user out of the URL.

### scrub_password

Set to false to skip scrubbing password out of the URL.

### user_ip_obfuscator_secret

A string used hash IP addresses when obfuscating them.

### randomize_scrub_length

**Default** `true`

When true randomizes the number of asterisks used to display scrubbed fields.

### uncaught_exception_level

**Default** `error`

Use this field to select a different level for uncaught errors (like `critical`,
or `warning`).

### scrub_headers

**Default** `["Authentication"]`

The headers to scrub.

### sidekiq_threshold

**Default** `0`

The number of job re-tries before reporting an error to Rollbar via Sidekiq.
Ignored unless you've called `use_sidekiq`.

### verify_ssl_peer

**Default** `true`

By default we use `OpenSSL::SSL::VERIFY_PEER` for SSL. Although we don't
recommend changing it, you can disable peer verification in case you experience
SSL connection problems.

### use_async

**Default** `false`

When `true` indicates you wish to send data to Rollbar asynchronously. If
installed, uses `girl_friday`, otherwise defaults to `Thread`.

### use_eventmachine

**Default** `false`

When `true` indicates you wish to send data to Rollbar with `eventmachine`.
Won't work unless `eventmachine` is installed.

### use_exception_level_filters_default

**Default** `false`

When `true` the notifier will use the `exception_level_filters` when reporting. It can be overriden using `:use_exception_level_filters` option. see [Exception level filters](https://github.com/rollbar/rollbar-gem#exception-level-filters)

### web_base

**Default** `'https://rollbar.com'`

The root of the web app that serves your rollbar data. Unless you're an
enterprise customer this should never change.

### write_to_file

**Default** `false`

If `true` writes all errors to a log file which can be sent with
`rollbar-agent`.
