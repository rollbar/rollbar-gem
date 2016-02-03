# Configuration Reference

TODO: SECTIONS(DELAYED JOB SUPPORT, ASYNC SUPPORT, WRITE TO FILE, PERSON TRACKING)

<!-- Sub:[TOC] -->

## access_token

**Required**

Sets the access token used to send payloads to rollbar.

Items sent through a given access token arrive in that access token's project
and respect the rate limits set on that access token.

## async_handler

If `config.use_async = true` explicitly sets the function used to send
asynchronous payloads to Rollbar. Should be an object that responds to `call`
Not needed if using one of the built in async reporters:

 * girl_friday
 * sucker_punch
 * Sidekiq
 * Resque
 * threading

## branch

**Default** "master"

Name of the checked-out source control branch.

## code_version

A string, up to 40 characters, describing the version of the application code.

Rollbar understands these formats:

 * semantic version (i.e. "2.1.12")
 * integer (i.e. "45")
 * git SHA (i.e. "3da541559918a808c2402bba5012f6c60b27661c")

## custom_data_method

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

## delayed_job_enabled

**Default** `true`


Set to false if you have `Delayed`  but do not wish to wrap Delayed jobs with a
Rollbar notifier.

## default_logger

**Default** `Logger.new(STDERR)`

What logger to use for printing debugging and informational messages during
operation.

## disable_monkey_patch

**Default** `false`

Disables monkey patching all non-core monkey patches. If you do this you'll
need to manually `use` an appropriate Rollbar middleware.

Especially useful if you're not using Rails or Sinatra.

## disable_core_monkey_patch

**Default** `false`

Disables our monkey patches in the ruby core. One mandatory monkey patch is left.
Be careful using this option as it may caused unexpected behavior in some situations.

## dj_threshold

**Default** 0 (Report *any* errors)

The number of job failures before reporting the failure to Rollbar.

## enabled

Whether or not to log messages and errors to Rollbar.

## endpoint

**Default** 'https://api.rollbar.com/api/1/item/'

Where to send the rollbar error messages. Only change this if you're an
enterprise customer or you're proxying our servers to get around applications
like Ghostery.

## environment

**Default** 'unspecified'

The environment ('production', 'development', 'testing', 'staging', etc.) in
which the code is running.

## exception_level_filters

**Default**
```ruby
{
  'ActiveRecord::RecordNotFound' => 'warning',
  'AbstractController::ActionNotFound' => 'warning',
  'ActionController::RoutingError' => 'warning'
}
```

A hash from Exception to level. Supported levels: "critical", "error",
"warning", "info", "debug", "ignore". Set to "ignore" to cause the exception not
to be reported at all.`

## failover_handlers

An array of backup handlers if the async handlers fail. Each should respond to
`call` and should receive a `payload`.

## filepath

For use with `write_to_file`. Indicates location of the rollbar log file being
tracked by [rollbar-agent](https://github.com/rollbar/rollbar-agent).

## framework

**Default** 'Plain'

Indicates which framework you're using. Common options include 'Rails',
'Sinatra', and 'Rack' to name a few.

## ignored_person_ids

**Default** `[]`

Ids of people whose reports you wish to ignore. Only works in conjunction with a
properly defined `person_method` or `person_id_method`.

## logger

The logger to use *instead of* the default logger. Especially useful in `scope`s
where you wish to send log messages elsewhere.

## payload_options

Extra data to send with the payload.

## person_method

Rails only: A string or symbol giving the name of the method on the controller.
Should return an object with an `id` method, and optionally `username` and
`email` methods.

If not using Rails:

Populate the Rack `person_data` key with a hash containing `:id`, and optionally
`:username` and `:email`.

## person_id_method

Rails only: a string or symbol giving the name of the method on the controller
which returns the current user's id (a string). Ignored if `person_method`
present.

## person_username_method

Rails only: a string or symbol giving the name of the method on the controller
which returns the current user's username. Ignored if `person_id_method` not
present. Ignored if `person_method` present.

## person_email_method

Rails only: a string or symbol giving the name of the method on the controller
which returns the current user's email address. Ignored if `person_id_method`
not present. Ignored if `person_method` present.

## populate_empty_backtraces

If you report a `new` exception, but do not `raise` it, the backtraces in Rollbar
will be empty. Set `populate_empty_backtraces` to `true` to have Rollbar load
the traces before sending them.

## report_dj_data

**Default** `true`

Set to `false` to skip automatic reporting of Delayed job data. This can be
handy if you manually report to Rollbar, or you have another way of catching and
reporting those errors.

## request_timeout

**Default** `3`

Set the request timeout for sending POST data to Rollbar.

## root

Set the server root, all stack frames outside that root are considered
'non-project' frames. Also used to setup Github linking.

## safely

**Default** `false`

When `true` evaluates `custom_data_method` returns `{}` if an error,
otherwise reports the error to Rollbar.

## scrub_fields

Fields to scrub out of the parsed request data. Will scrub from `GET`, `POST`,
url, and several other locations. Does not currently recurse into the full
payload.

## scrub_user

**Default** `true`

Set to false to skip scrubbing user out of the URL.

## scrub_password

Set to false to skip scrubbing password out of the URL.

## user_ip_obfuscator_secret

A string used hash IP addresses when obfuscating them.

## randomize_scrub_length

**Default** `true`

When true randomizes the number of asterisks used to display scrubbed fields.

## uncaught_exception_level

**Default** `error`

Use this field to select a different level for uncaught errors (like `critical`,
or `warning`).

## scrub_headers

**Default** `["Authentication"]`

The headers to scrub.

## sidekiq_threshold

**Default** `0`

The number of job re-tries before reporting an error to Rollbar via Sidekiq.
Ignored unless you've called `use_sidekiq`.

## verify_ssl_peer

**Default** `true`

By default we use `OpenSSL::SSL::VERIFY_PEER` for SSL. Although we don't
recommend changing it, you can disable peer verification in case you experience
SSL connection problems.

## use_async

**Default** `false`

When `true` indicates you wish to send data to Rollbar asynchronously. If
installed, uses `girl_friday`, otherwise defaults to `Threading`.

## use_eventmachine

**Default** `false`

When `true` indicates you wish to send data to Rollbar with `eventmachine`.
Won't work unless `eventmachine` is installed.

## web_base

**Default** `'https://rollbar.com'`

The root of the web app that serves your rollbar data. Unless you're an
enterprise customer this should never change.

## write_to_file

**Default** `false`

If `true` writes all errors to a log file which can be sent with
`rollbar-agent`.
