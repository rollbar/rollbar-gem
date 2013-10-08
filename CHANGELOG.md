# Change Log

**0.11.2**
- Test rake task now works properly if force_ssl is true

**0.11.1**
- `config.exception_level_filters` can now take a callable instead of a string. The exception instance will be passed to the callable.

**0.11.0**
- Changed default environment name from `'production'` to `'unspecified'`

**0.10.14**
- Fixed compatability issue with better_errors 1.0

**0.10.13**
- Added `code_version` configuration setting

**0.10.12**
- Exclude HTTP_COOKIE header (since cookies are already included in parsed form)

**0.10.11**
- Fix usage of custom Sidekiq options

**0.10.10**
- Add support for sucker_punch asynchronous handling

**0.10.9**
- Fix regression introduced in 0.10.7 when ActiveRecord is not present.

**0.10.8**
- Better handling of internal errors. Internal errors (errors that occur while reporting something to Rollbar) are now themselves reported to Rollbar. If that fails, a failsafe message will be reported, and if that fails, the error will be logged as it is now.
- Fix bug reporting exceptions with backtraces containing frames that don't match our regex.

**0.10.7**
- Add ability to report form validation errors
- Add MIT license to gemspec

**0.10.6**
- Fix json dump when rack.errors is an IO stream

**0.10.5**
- Add built-in support for Sidekiq as async handler

**0.10.4**
- Fix exception in the exception catcher when Rollbar is disabled

**0.10.3**
- Rework how request params are extracted so that json params are properly extracted in rails 4.0
- Fix rollbar:test rake task

**0.10.2**
- Require hooks at configuration time instead of gem load time

**0.10.1**
- Fix regression in 0.10.0 reporting exceptions in development environments and rails < 3.2 apps.

**0.10.0**
- Fixed bug causing duplicate reports when used inside Rails in production with the default error pages. Bumping version to 0.10.0 in case this turns out to be backwards-incompatible for some use cases (i.e. for applications that were relying on the duplicate report that has now been removed).

**0.9.14**
- Added `custom_data_method` config option. If set, it should be a lambda that returns a hash.
- Changed initializer template to disable reporting from the 'test' environment.

**0.9.13**
- Add test for PUT params
- Parse json params when content-type is application/json
- Fix concurrency issue
- Remove redundant `GET` and `POST` keys from request payload (they're already included in `params`)

**0.9.12**
- Fix compatibility issue with Rails 4 / Ruby 2 (thanks [johnknott](https://github.com/johnknott))

**0.9.11**
- Provide a default environment name when used outside of Rails and none is set

**0.9.10**
- Add :secret_token to default scrub_fields list
- Session params are now scrubbed

**0.9.9**
- Fix capistrano recipe on 1.9.2 ([#36](https://github.com/rollbar/rollbar-gem/pull/36))
- Add example of disable "test" env to initializer template

**0.9.8**
- Fix bug introduced in 0.9.0 where setting `config.enabled = false` in `config/initializers/rollbar.rb` would be overwritten by subsequent calls to `Rollbar.configure` (as happens normally when using inside Rails).

**0.9.7**
- Use `include?` instead of `in?` for filtering (see [#34](https://github.com/rollbar/rollbar-gem/pull/34))

**0.9.6**
- Fix for Rails 4 support

**0.9.5**
- Support for configuring the access token with an environment variable.

**0.9.4**
- Fixed issue using rollbar-gem outside of Rails
- Clarified the "details: " link log message

**0.9.3**
- Added configuration setting to specify gems that should be considered part of the Rollbar project, making frames from these gems show up automatically uncollapsed in tracebacks appearing on the website.

**0.9.2**
- Added [Capistrano integration](https://github.com/rollbar/rollbar-gem/pull/27)

**0.9.1**
- Add support to play nicely with Better Errors.

**0.9.0**
- Behavior change: start configuration as `@enabled = false`, and set to true when `configure` is called. This addresses an issue using Rollbar without the environment initialized. Such reports would always fail (since there would be no access token), but now they won't be attempted.

**0.8.3**
- Relax multi_json dependency to 1.5.0

**0.8.2**
- Adding back rake task exception reporting after fixing load order issue

**0.8.1**
- Reverting rake task exception reporting until we can track down a load order issue reported by a few users

**0.8.0**
- Rename to rollbar

**0.7.1**
- Fix ratchetio:test rake task when project base controller is not called ApplicationController

**0.7.0**
- Exceptions in Rake tasks are now automatically reported.

**0.6.4**
- Bump multi_json dependency version to 1.6.0

**0.6.3**
- Bump multi_json dependency version to 1.5.1

**0.6.2**
- Added EventMachine support

**0.6.1**
- Added a log message containing a link to the instance. Copy-paste the link into your browser to view its details in Ratchet.
- Ratchetio.report_message now returns 'ignored' or 'error' instead of nil when a message is not reported for one of those reasons, for consistency with Ratchetio.report_exception.

**0.6.0**
- POSSIBLE BREAKING CHANGE: Ratchetio.report_exception now returns 'ignored', 'disabled', or 'error' instead of nil when the exception is not reported for one of those reasons. It still returns the payload upon success.
- Request data is now parsed from the rack environment instead of from within the controller, addressing issue #10.
- Add Sidekiq middleware for catching workers' exceptions
- Replaced activesupport dependency with multi_json

**0.5.5**
- Added activesupport dependency for use without Rails 

**0.5.4**
- Added new default scrub params

**0.5.3**
- Add `Ratchetio.silenced`; which allows disabling reporting for a given block. See README for usage.

**0.5.2**
- Fix compat issue with delayed_job below version 3. Exceptions raised by delayed_job below version 3 will not be automatically caught; upgrade to v3 or catch and report by hand. 

**0.5.1**
- Save the exception uuid in `env['ratchetio.exception_uuid']` for display in user-facing error pages.

**0.5.0**
- Add support to report exceptions raised in delayed_job.

**0.4.11**
- Allow exceptions with no backtrace (e.g. StandardError subclasses)

**0.4.10**
- Fix compatability issue with ruby 1.8

**0.4.9**
- Start including a UUID in reported exceptions
- Fix issue with scrub_fields, and add `:password_confirmation` to the default list

**0.4.8**
- Add ability to send reports asynchronously, using girl_friday or Threading by default.
- Add ability to save reports to a file (for use with ratchet-agent) instead of sending across to Ratchet servers.

**0.4.7**
- Sensitive params now scrubbed out of requests. Param name list is customizable via the `scrub_fields` config option.

**0.4.6**
- Add support to play nicely with Goalie.

**0.4.5**
- Add `default_logger` config option. It should be a lambda that will return the logger to use if no other logger is configured (i.e. no logger is set by the Railtie hook). Default: `lambda { Logger.new(STDERR) }`

**0.4.4**
- Add `enabled` runtime config flag. When `false`, no data (messages or exceptions) will be reported.

**0.4.3**
- Add RSpec test suite. A few minor code changes.

**0.4.2**
- Add "ignore" filter level to completely ignore exceptions by class.

**0.4.1**
- Recursively filter files out of the params hash. Thanks to [trisweb](https://github.com/trisweb) for the pull request.

**0.4.0**
 
- Breaking change to make the "person" more configurable. If you were previously relying on your `current_member` method being called to return the person object, you will need to add the following line to `config/initializers/ratchetio.rb`:
    
    config.person_method = "current_member"

- Person id, username, and email method names are now configurable -- see README for details.
