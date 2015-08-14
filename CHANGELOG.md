# Change Log

## 2.2.0

New feature:

- Allow passing a different access_token in extra parameters. This can be useful if you have a single project that should report to different Rollbar projects.

Bug fix:

- Allow having multiple uploads for the same parameter. Thanks @mdominiak.

## 2.1.1

Bug fix:

- Don't swallow exceptions on `Rollbar::ActiveJob` module. With this fix we don't break the ActiveJob backends' features like retries.

## 2.1.0

New feature:

- If you use `ActiveJob`, you can now include the `Rollbar::ActiveJob` module into your ActiveJob classes. Then, errors happening in your jobs will be automatically reported to Rollbar.

## 2.0.2

Bug fixes:

- Fix capistrano task cause a namespace conflict between JSON and Rollbar::JSON.

## 2.0.1

Bug fixes:

- Remove requires for multi_json gem. Thanks @albertyw.

## 2.0.0

Possibly breaking changes:

- If active_support version < 4.1.0 is installed, this gem will now monkeypatch `BasicSocket#to_json`. This is needed to work around a bug causing JSON serialization to fail when the payload contains a Socket instance. We don't expect this to break anything for anyone, unless you are using active_support version < 4.1.0 and also happened to be relying on the buggy Socket serialization behavior.

Bug fixes:

- Use the JSON gem or native by default. Along with the aforementioned monkeypatch, this fixes the existing bug in active_support < 4.1.0 serializing Socket instances. To disable the monkeypatch, set `config.disable_core_monkey_patch = true`.
- Add Encoding module, with Encoder and LegacyEncoder classes. This fixes some issues with ISO-8859 strings

Other changes:

- Update README.md and warn about upgrade to capistrano >= 3.1
- Fix error in code example for custom Async handlers

## 1.5.3

Bug fixes:

- Run `rollbar-rails-runner` in the context of `Rails` module so we avoid namespace conflicts. See [#242](https://github.com/rollbar/rollbar-gem/pull/242)

## 1.5.2

Bug fixes:

- Fix minimum body truncation strategy when the payload is a message without exception. See [#240](https://github.com/rollbar/rollbar-gem/pull/240)

## 1.5.1

Bug fixes:

- Fixed crashes when `Configuration#custom_data_method` fails. Now a report for that crash will be reported also. See [#235](https://github.com/rollbar/rollbar-gem/pull/235)

## 1.5.0

Bug fixes:

- Fixed support for extended unicode characters. See [#234](https://github.com/rollbar/rollbar-gem/pull/234)

Possible breaking changes:

- Some characters that previously were stripped are now encoded. This could cause some events to be grouped into new items by Rollbar.


## 1.4.5

Bug fixes:

- Fixed internal error reporting IpSpoofAttackErrors. See [#233](https://github.com/rollbar/rollbar-gem/pull/233)
- Removed duplicated `schedule_payload` definition. See [#231](https://github.com/rollbar/rollbar-gem/pull/231)


## 1.4.4

New features:

- Added configuration option to gather backtraces for exceptions that don't already have one (i.e. if you do `Rollbar.error(Exception.new)`). Set `config.populate_empty_backtraces = true` to enable it. See [#206](https://github.com/rollbar/rollbar-gem/pull/206)

Bug fixes:

- Reverted capistrano change as it causes problems in some setups. See [#210](https://github.com/rollbar/rollbar-gem/pull/210)

Other:

- Refactored the Sidekiq handler (no changes to the interface). See [#197](https://github.com/rollbar/rollbar-gem/pull/197)

## 1.4.3

New features:

- The current thread's scope can now be modified using `Rollbar.scope!`. This can be used to provide context data which will be included if the current request/job/etc. later throws an exception. See [#212](https://github.com/rollbar/rollbar-gem/pull/212)

Bug fixes:

- Remove duplicate `#configure` definition. See [#207](https://github.com/rollbar/rollbar-gem/pull/207)
- In the capistrano task, don't override set variables. See [#210](https://github.com/rollbar/rollbar-gem/pull/210)
- Style fix in sidekiq handler. See [#209](https://github.com/rollbar/rollbar-gem/pull/209)

## 1.4.2

Bug fixes:

- Fix null 'context' in internal error reports. See [#208](https://github.com/rollbar/rollbar-gem/pull/208)

## 1.4.1

Bug fixes:

- Fix internal error when ActiveRecord was present, but not used. See [#204](https://github.com/rollbar/rollbar-gem/pull/204)

## 1.4.0

Possible breaking changes:

- `exception_level_filters` is now applied only to "uncaught" errors (i.e. those detected by middlewares) but not to direct calls to `Rollbar.error`. If you were previously using `Rollbar.error` (or `Rollbar.warning`, etc.), the new behavior is *probably* desirable, but if it isn't, you can get the old behavior via `Rollbar.error(e, :use_exception_level_filters => true)`. The middlewares that ship with the gem also now pass this new flag.

## 1.3.2

Bug fixes:

- Fix bug with the `write_to_file` method where values were dumped as ruby hashes instead of json. See [#198](https://github.com/rollbar/rollbar-gem/pull/198)

## 1.3.1

Bug fixes:

- Fix bug with smart truncation for messages. See [#195](https://github.com/rollbar/rollbar-gem/issues/195) and [#196](https://github.com/rollbar/rollbar-gem/issues/196)
- Safely catch exceptions in `process_payload` when called from an async handler. See [#196](https://github.com/rollbar/rollbar-gem/pull/196)


## 1.3.0

Performance improvements:

- In the Rails, Rack, and Sinatra middlewares, request data is now gathered only when needed instead of in advance on every request. See [#194](https://github.com/rollbar/rollbar-gem/pull/194); fixes [#180](https://github.com/rollbar/rollbar-gem/issues/180)

Possible breaking changes:

- If the scope's `:request` or `:context` value is an object that responds to `:call`, those values will now be called when a a report is made (and their result will be used in the payload). This is very unlikely to affect anyone, but we're releasing this as a version bump just to be safe.


## 1.2.13

New features:

- Person tracking for Rack/Sinatra apps. See [#192](https://github.com/rollbar/rollbar-gem/pull/192)

Bug fixes:

- Fix `rollbar:test` rake task (regression from 1.2.12); see [985c091](https://github.com/vyrak/rollbar-gem/commit/985c091ad58ae4f4c6997dd356497b4e5a2be498)

## 1.2.12

Bug fixes:

- Fix bug introduced in 1.2.11 that broke the sidekiq async handler. See [#190](https://github.com/rollbar/rollbar-gem/issues/190)
- Skip Rake monkeypatch for Rake < 0.9.0. Fixes [#187](https://github.com/rollbar/rollbar-gem/issues/187)


## 1.2.11

New features:

- Improved truncation algorithm, so that more kinds of large payloads will be successfully brought below the 128kb limit and successfully reported. See [#185](https://github.com/rollbar/rollbar-gem/pull/185)

Bug fixes:

- Fix issue where using Rollbar outside of a web process was prone to errors being silently ignored. See [#183](https://github.com/rollbar/rollbar-gem/issues/183)


## 1.2.10

Bug fixes:

- Fix bug introduced in 1.2.8 with Sidekiq version < 3. See [#181](https://github.com/rollbar/rollbar-gem/issues/181)


## 1.2.9

Bug fixes:

- Fix issue causing request and person data to not be collected for RoutingErrors. See [#178](https://github.com/rollbar/rollbar-gem/pull/178)


## 1.2.8

New features:

- Add config option to not monkeypatch `Rack::Builder`. See [#169](https://github.com/rollbar/rollbar-gem/pull/169)
- Track server PID. See [#171](https://github.com/rollbar/rollbar-gem/pull/171)


Bug fixes:

- Remove internal calls to deprecated methods. See [#166](https://github.com/rollbar/rollbar-gem/pull/166)
- Fix an intermittently failing test. See [#167](https://github.com/rollbar/rollbar-gem/pull/167)
- Fix configuration issue when an initializer calls `Thread.new` before Rollbar is initialized. See [#170](https://github.com/rollbar/rollbar-gem/pull/170) and [#168](https://github.com/rollbar/rollbar-gem/pull/168)
- Fix infinite loop with cyclic inner exceptions. See [#172](https://github.com/rollbar/rollbar-gem/pull/172)


## 1.2.7

Bug fixes:
- Restore `exception_level_filters` feature, which was inadvertently removed in 1.2.0. See [#160](https://github.com/rollbar/rollbar-gem/pull/160) 
- Fix bug where rollbar_url incorrectly handled comma-separated X-Forwarded-Proto header values. See [#112](https://github.com/rollbar/rollbar-gem/issues/112)


## 1.2.6

Bug fixes:

- Fix bug in non-Rails environments. See [#155](https://github.com/rollbar/rollbar-gem/pull/155)
- Fix intermittent test failures


## 1.2.5

Bug fixes:

- Fix issues handling hashes, arrays, and other values as the raw POST body. See [#153](https://github.com/rollbar/rollbar-gem/pull/153)


## 1.2.4

Bug fixes:

- Fix issue where requiring 'rack' unnecessarily broke things in non-rack apps. See [#150](https://github.com/rollbar/rollbar-gem/pull/150)


## 1.2.3

Bug fixes:

- Bring back `enforce_valid_utf8`, which got lost in the 1.2.0 upgrade. See [#148](https://github.com/rollbar/rollbar-gem/pull/148)
- Fix bug with raw post extraction for application/json requests. See [#147](https://github.com/rollbar/rollbar-gem/pull/147)


## 1.2.2

Bug fixes:

- Fix issue with delayed_job and Rollbar.report_exception (bug introduced in 1.2.0). See [#145](https://github.com/rollbar/rollbar-gem/issues/145)
- Explicitly require 'rack' in request_data_extractor. See [#144](https://github.com/rollbar/rollbar-gem/pull/144)


## 1.2.1

Bug fixes:

- Revert change made as part of 1.2.0 where all procs in the payload would be evaluated. See [#143](https://github.com/rollbar/rollbar-gem/pull/143).


## 1.2.0

New features:

- Added new, much nicer interface for sending exceptions and messages to Rollbar. This is a backwards-compatible release: the old interface (`report_message`, `report_exception`, `report_message_with_request`) is deprecated but will continue to work at least until 2.0.
  
  See the docs for [basic](https://github.com/rollbar/rollbar-gem#caught-exceptions-and-messages) and [advanced](https://github.com/rollbar/rollbar-gem#advanced-usage) usage for a guide to the new interface. If you've used [rollbar.js](https://github.com/rollbar/rollbar.js), it will be familiar.

---

## 1.1.0

New features:

- Support nested exceptions for Ruby 2.1. See [#136](https://github.com/rollbar/rollbar-gem/pull/136). NOTE: for exceptions that have causes, this will change how they are grouped in Rollbar. If you have custom grouping rules, they will need to be updated to replace `body.trace.exception` with `body.trace_chain[0].exception` to maintain the same behavior for these exceptions.
- New feature: `failover_handlers`. You can specify a list of async handlers, which will be tried in sequence upon failure. See [#135](https://github.com/rollbar/rollbar-gem/pull/135).

Bug fixes:

- Fix handling of utf8 sequences in payload symbols. See [#131](https://github.com/rollbar/rollbar-gem/pull/131). Thanks [@kroky](https://github.com/kroky) for the fix and [@jondeandres](https://github.com/jondeandres) for reviewing.
- Fix logic bugs in assignments for `scrub_fields` and `scrub_headers`. See [#137](https://github.com/rollbar/rollbar-gem/pull/137)

---

## 1.0.1

Bug fixes:

- Use the payload's access token for the X-Rollbar-Access-Token header, instead of the configured access token. Fixes an issue where payloads would be reported into the wrong project when sent via Resque. See [#128](https://github.com/rollbar/rollbar-gem/pull/128). Thanks to [@jondeandres](https://github.com/jondeandres) for the fix.

## 1.0.0

Bug fixes:

- Strip out invalid UTF-8 characters from payload keys/values, fixes [#85](https://github.com/rollbar/rollbar-gem/issues/85)


Misc:

- Clean up some unused requires
- Bumping to 1.0 due to the suggestion in [#119](https://github.com/rollbar/rollbar-gem/issues/119)

---

## 0.13.2

- Sidekiq payload is no longer mutated when Rollbar reports a Sidekiq job exception
- Fix sucker_punch async reporting when using a forking application server such as Unicorn (`preload_app true`). Jobs are now instantiated for every report instead of a reused global job instance


## 0.13.1
- Silence warning when using project_gems= with regexp [#120](https://github.com/rollbar/rollbar-gem/pull/120)


## 0.13.0

- Hook for delayed_job no longer a plugin, will now only ever be initialized once
- New configuration option `delayed_job_enabled` that defaults to true
- Potentially breaking change if using delayed_job: if you disabled the delayed_job plugin previously, please remove that code and instead set the new configuration option `delayed_job_enabled` to false


## 0.12.20
- Fix asynchronous reports with sidekiq version < 2.3.2
- Support for specifying multiple project_gems with regex [#114](https://github.com/rollbar/rollbar-gem/pull/114)

## 0.12.19
- Fix rake test task in production
- Report an additional simple error message in the rake test task

## 0.12.18
- Insert RollbarRequestStore middleware at the end in case the ActiveRecord ConnectionManagement middleware isn't used
- Scope Capistrano 3 task by server role [#110](https://github.com/rollbar/rollbar-gem/pull/110)

## 0.12.17
- Replace usage of `puts` with a configurable logger in different areas of the notifier
- Fix error in `RollbarRequestStore` when `rollbar_person_data` isn't defined for a controller

## 0.12.16
- Scrub fields are now converted to a regular expression for broader param name matching
- Save ActionDispatch request_id in reports if present
- Added proper Sidekiq 3 error handler
- Removed usage of ActiveSupport's `Object#try` in different areas of the notifier
- Added a configurable request timeout for reports (defaults to 3 seconds)
- Fix circular json exception handling in Rails 4.1

## 0.12.15
- Send X-Rollbar-Access-Token http header along with payloads

## 0.12.14
- Added ability to scrub request headers
- Added flag to disable reporting of Delayed::Job job data when handling uncaught exceptions that happen in jobs
- New `report_message_with_request` that allows reporting request and person data, similar to `report_exception`
- Changed various exception handlers to catch `Exception` subclasses instead of only `StandardError`s
- Added Capistrano 3 support

## 0.12.13
- Add a little more debugging information for 'payload too large' errors
- Pushing new gem to fix errant 32kb size limit in the rubygems copy of 0.12.12

## 0.12.12
- Changes to support Engine Yard add-on setup

## 0.12.11
- Raise payload size limit to 128k

## 0.12.10
- Log payloads that are too large to be sent to Rollbar
- Don't record controller context if request route info isn't readily available (ex. non-Rails)

## 0.12.9
- Fixed delayed job regression introduced in 0.12.5 by re-raising caught exceptions
- Removed Active Support call introduced in 0.12.6 to remove rails dependency in `report_exception`

## 0.12.8
- Added funcitonality to walk the payload and truncate strings to attempt to reduce size if the payload is too large (more than 32kb total)

## 0.12.7
- Fix error reporting errors when route controller or action is nil (bug introduced in 0.12.4)

## 0.12.6
- Added [#78](https://github.com/rollbar/rollbar-gem/pull/78), added configuration option to ignore specific person exceptions

## 0.12.5
- Fixed SIGSEGV with the delayed_job plugin and Ruby 2.1.0

## 0.12.4
- Record controller context (controller#action) in reported items

## 0.12.3
- Change rollbar_request_store middleware to only grab required person data properties by using rollbar_person_data

## 0.12.2
- Added ability to specify level for manually reported exceptions

## 0.12.1
- Fix syntax error in `config.use_sidekiq` usage example

## 0.12.0
- Added [#73](https://github.com/rollbar/rollbar-gem/pull/73), enhanced Sidekiq and SuckerPunch configuration. NOTE: The old `Rollbar::Configuration#use_sidekiq=` and `Rollbar::Configuration#use_sucker_punch=` methods are now deprecated, see the docs for updated usage information.

## 0.11.8
- Make sure the person method exists for the controller before trying to extract person data

## 0.11.7
- Remove ActiveRecord railtie requirement introduced in 0.11.6

## 0.11.6
- Adding new middleware that grabs possible database-hitting person data before the rake connection pool cleanup middleware

## 0.11.5
- Fix rake test task when Authlogic is present

## 0.11.4
- Respect different proxy headers when building the request url

## 0.11.3
- Make sure the environment is valid at item sending time so that it isn't set incorrectly during configuration

## 0.11.2
- Test rake task now works properly if force_ssl is true

## 0.11.1
- `config.exception_level_filters` can now take a callable instead of a string. The exception instance will be passed to the callable.

## 0.11.0
- Changed default environment name from `'production'` to `'unspecified'`

## 0.10.14
- Fixed compatability issue with better_errors 1.0

## 0.10.13
- Added `code_version` configuration setting

## 0.10.12
- Exclude HTTP_COOKIE header (since cookies are already included in parsed form)

## 0.10.11
- Fix usage of custom Sidekiq options

## 0.10.10
- Add support for sucker_punch asynchronous handling

## 0.10.9
- Fix regression introduced in 0.10.7 when ActiveRecord is not present.

## 0.10.8
- Better handling of internal errors. Internal errors (errors that occur while reporting something to Rollbar) are now themselves reported to Rollbar. If that fails, a failsafe message will be reported, and if that fails, the error will be logged as it is now.
- Fix bug reporting exceptions with backtraces containing frames that don't match our regex.

## 0.10.7
- Add ability to report form validation errors
- Add MIT license to gemspec

## 0.10.6
- Fix json dump when rack.errors is an IO stream

## 0.10.5
- Add built-in support for Sidekiq as async handler

## 0.10.4
- Fix exception in the exception catcher when Rollbar is disabled

## 0.10.3
- Rework how request params are extracted so that json params are properly extracted in rails 4.0
- Fix rollbar:test rake task

## 0.10.2
- Require hooks at configuration time instead of gem load time

## 0.10.1
- Fix regression in 0.10.0 reporting exceptions in development environments and rails < 3.2 apps.

## 0.10.0
- Fixed bug causing duplicate reports when used inside Rails in production with the default error pages. Bumping version to 0.10.0 in case this turns out to be backwards-incompatible for some use cases (i.e. for applications that were relying on the duplicate report that has now been removed).

## 0.9.14
- Added `custom_data_method` config option. If set, it should be a lambda that returns a hash.
- Changed initializer template to disable reporting from the 'test' environment.

## 0.9.13
- Add test for PUT params
- Parse json params when content-type is application/json
- Fix concurrency issue
- Remove redundant `GET` and `POST` keys from request payload (they're already included in `params`)

## 0.9.12
- Fix compatibility issue with Rails 4 / Ruby 2 (thanks [johnknott](https://github.com/johnknott))

## 0.9.11
- Provide a default environment name when used outside of Rails and none is set

## 0.9.10
- Add :secret_token to default scrub_fields list
- Session params are now scrubbed

## 0.9.9
- Fix capistrano recipe on 1.9.2 ([#36](https://github.com/rollbar/rollbar-gem/pull/36))
- Add example of disable "test" env to initializer template

## 0.9.8
- Fix bug introduced in 0.9.0 where setting `config.enabled = false` in `config/initializers/rollbar.rb` would be overwritten by subsequent calls to `Rollbar.configure` (as happens normally when using inside Rails).

## 0.9.7
- Use `include?` instead of `in?` for filtering (see [#34](https://github.com/rollbar/rollbar-gem/pull/34))

## 0.9.6
- Fix for Rails 4 support

## 0.9.5
- Support for configuring the access token with an environment variable.

## 0.9.4
- Fixed issue using rollbar-gem outside of Rails
- Clarified the "details: " link log message

## 0.9.3
- Added configuration setting to specify gems that should be considered part of the Rollbar project, making frames from these gems show up automatically uncollapsed in tracebacks appearing on the website.

## 0.9.2
- Added [Capistrano integration](https://github.com/rollbar/rollbar-gem/pull/27)

## 0.9.1
- Add support to play nicely with Better Errors.

## 0.9.0
- Behavior change: start configuration as `@enabled = false`, and set to true when `configure` is called. This addresses an issue using Rollbar without the environment initialized. Such reports would always fail (since there would be no access token), but now they won't be attempted.

## 0.8.3
- Relax multi_json dependency to 1.5.0

## 0.8.2
- Adding back rake task exception reporting after fixing load order issue

## 0.8.1
- Reverting rake task exception reporting until we can track down a load order issue reported by a few users

## 0.8.0
- Rename to rollbar

## 0.7.1
- Fix ratchetio:test rake task when project base controller is not called ApplicationController

## 0.7.0
- Exceptions in Rake tasks are now automatically reported.

## 0.6.4
- Bump multi_json dependency version to 1.6.0

## 0.6.3
- Bump multi_json dependency version to 1.5.1

## 0.6.2
- Added EventMachine support

## 0.6.1
- Added a log message containing a link to the instance. Copy-paste the link into your browser to view its details in Ratchet.
- Ratchetio.report_message now returns 'ignored' or 'error' instead of nil when a message is not reported for one of those reasons, for consistency with Ratchetio.report_exception.

## 0.6.0
- POSSIBLE BREAKING CHANGE: Ratchetio.report_exception now returns 'ignored', 'disabled', or 'error' instead of nil when the exception is not reported for one of those reasons. It still returns the payload upon success.
- Request data is now parsed from the rack environment instead of from within the controller, addressing issue #10.
- Add Sidekiq middleware for catching workers' exceptions
- Replaced activesupport dependency with multi_json

## 0.5.5
- Added activesupport dependency for use without Rails

## 0.5.4
- Added new default scrub params

## 0.5.3
- Add `Ratchetio.silenced`; which allows disabling reporting for a given block. See README for usage.

## 0.5.2
- Fix compat issue with delayed_job below version 3. Exceptions raised by delayed_job below version 3 will not be automatically caught; upgrade to v3 or catch and report by hand.

## 0.5.1
- Save the exception uuid in `env['ratchetio.exception_uuid']` for display in user-facing error pages.

## 0.5.0
- Add support to report exceptions raised in delayed_job.

## 0.4.11
- Allow exceptions with no backtrace (e.g. StandardError subclasses)

## 0.4.10
- Fix compatability issue with ruby 1.8

## 0.4.9
- Start including a UUID in reported exceptions
- Fix issue with scrub_fields, and add `:password_confirmation` to the default list

## 0.4.8
- Add ability to send reports asynchronously, using girl_friday or Threading by default.
- Add ability to save reports to a file (for use with ratchet-agent) instead of sending across to Ratchet servers.

## 0.4.7
- Sensitive params now scrubbed out of requests. Param name list is customizable via the `scrub_fields` config option.

## 0.4.6
- Add support to play nicely with Goalie.

## 0.4.5
- Add `default_logger` config option. It should be a lambda that will return the logger to use if no other logger is configured (i.e. no logger is set by the Railtie hook). Default: `lambda { Logger.new(STDERR) }`

## 0.4.4
- Add `enabled` runtime config flag. When `false`, no data (messages or exceptions) will be reported.

## 0.4.3
- Add RSpec test suite. A few minor code changes.

## 0.4.2
- Add "ignore" filter level to completely ignore exceptions by class.

## 0.4.1
- Recursively filter files out of the params hash. Thanks to [trisweb](https://github.com/trisweb) for the pull request.

## 0.4.0

- Breaking change to make the "person" more configurable. If you were previously relying on your `current_member` method being called to return the person object, you will need to add the following line to `config/initializers/ratchetio.rb`:

    config.person_method = "current_member"

- Person id, username, and email method names are now configurable -- see README for details.
