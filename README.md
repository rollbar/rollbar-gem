This is a forked version of https://github.com/rollbar/rollbar-gem.

## High Level Summary
This forked implementation allows the `Rollbar` module to send messages to Datadog as well as Rollbar (assuming Datadog has been set up in the application).

## Detailed Changes
The class `Notifier` in the original gem contains two methods that directly reference the Rollbar API to which messages are sent:
* `#send_using_eventmachine`
* `#send_body`

These two methods are overridden in this forked gem in order to inject code to add messages to the application log. Assuming Datadog has been set up in the application, the Datadog agent should be tailing the application log in order to send the logged messages to Datadog. This, in effect, allows messages sent via the `Rollbar` module to be sent to Datadog as well as to Rollbar.

The exception to this is the handling of uncaught exceptions. Datadog should already be set up to log uncaught exceptions in the application, so it would not be necessary to also add those messages to the application log for the Datadog agent to pick up.
