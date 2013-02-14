# Change Log

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
