# Upgrading

## From 1.1.0 or lower to 1.2.0

The public interface has been rewritten entirely in 1.2.0 to be more versatile and in-line with the new interface established recently in rollbar.js. The main `#report_message` and `#report_exception` methods are now deprecated in favor of the new `#log`, `#debug` `#info`, `#warn`, `#error` and `#critical` methods.

The new methods will accept any number of arguments. The last string argument is used as a message/description, the last exception argument is used as the reported exception, and the last hash is used as the extra data (except for `log` which requires an additional level string as the first argument).

The old methods will still function properly but it is recommended to migrate to the new interface whenever possible. You can migrate simply by doing the following:

1. Replace all occurrences of `#report_exception` with `#error`, or `#log` with a custom level if set in your existing `#report_exception` call.

2. Replace all occurrences of `#report_message` and `#report_message_with_request` with the one of the logging methods `#debug` through `#critical`.

3. The argument order can stay the same.

If using a Rack application, `request_data` and `person_data` will not longer be required to be passed in when logging messages or exceptions. The Rack, Sinatra or Rails middleware is responsible to extract the data and pass it to Rollbar.

If **not** using any Rack application, then you will need to use the `#scope` or `#scoped` method to set this data manually:

```ruby
notifier = Rollbar.scope({
  :request => rollbar_request_data,
  :person => rollbar_person_data
})

# will contain request parameters and person data
notifier.warning('User submitted invalid form data')
```

The `#scoped`method allows to change the payload options for a specific code block. This is the method used by the Rack and Rails middlewares.

```ruby
scope = { :request => rollbar_request_data,
	      :person => rollbar_person_data
}

Rollbar.scoped(scope) do
  begin
      # code that will raise
  rescue => e
    Rollbar.error(e)
  end
end
```
