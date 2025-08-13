<p align="center">
  <img alt="rollbar-logo" src="https://user-images.githubusercontent.com/3300063/207964480-54eda665-d6fe-4527-ba51-b0ab3f41f10b.png" />
</p>

<h1 align="center">Rollbar Ruby Gem</h1>

<p align="center">
  <strong>Proactively discover, predict, and resolve errors in real-time with <a href="https://rollbar.com">Rollbar’s</a> error monitoring platform. <a href="https://rollbar.com/signup/">Start tracking errors today</a>!</strong>
</p>


[![Build Status](https://github.com/rollbar/rollbar-gem/workflows/Rollbar-gem%20CI/badge.svg?tag=latest)](https://github.com/rollbar/rollbar-gem/actions)
[![Gem Version](https://badge.fury.io/rb/rollbar.svg)](http://badge.fury.io/rb/rollbar)


---

[Rollbar](https://rollbar.com) is a real-time exception reporting service for Ruby and other languages. The Rollbar service will alert you of problems with your code and help you understand them in a ways never possible before. We love it and we hope you will too.

Rollbar-gem is the SDK for Ruby apps and includes support for apps using Rails, Sinatra, Rack, plain Ruby, and other frameworks.


## Key benefits of using Rollbar Ruby Gem are:

- **Frameworks:** Rollbar Ruby Gem supports popular Ruby frameworks such as <a href="https://docs.rollbar.com/docs/rails">Rails</a>, <a href="https://docs.rollbar.com/docs/sinatra">Sinatra</a>, <a href="https://docs.rollbar.com/docs/grape">Grape</a> and more.
- **Integrations:** Rollbar Ruby has integrations for <a href="https://docs.rollbar.com/docs/resque-integration">Resque</a>, <a href="https://docs.rollbar.com/docs/activejob-integration">ActiveJob</a>, <a href="https://docs.rollbar.com/docs/using-with-rollbar-agent">rollbar-agent</a>, <a href="https://docs.rollbar.com/docs/sidekiq-integration">Sidekiq</a> and more!
- **Automatic error grouping:** Rollbar aggregates Occurrences caused by the same error into Items that represent application issues. <a href="https://docs.rollbar.com/docs/grouping-occurrences">Learn more about reducing log noise</a>.
- **Advanced search:** Filter items by many different properties. <a href="https://docs.rollbar.com/docs/search-items">Learn more about search</a>.
- **Customizable notifications:** Rollbar supports several messaging and incident management tools where your team can get notified about errors and important events by real-time alerts. <a href="https://docs.rollbar.com/docs/notifications">Learn more about Rollbar notifications</a>.


## Setup Instructions

1. [Sign up for a Rollbar account](https://rollbar.com/signup)
2. Follow the [Getting Started](https://docs.rollbar.com/docs/ruby#section-getting-started) instructions in our [Ruby SDK docs](https://docs.rollbar.com/docs/ruby) to install rollbar-gem and configure it for your platform.

## Usage and Reference

For complete usage instructions and configuration reference, see our [Ruby SDK docs](https://docs.rollbar.com/docs/ruby).

## Compatibility

Version >= 3.0.0 is compatible with Ruby >= 2.0.0.

Version >= 2.19.0 is compatible with Ruby >= 1.9.3.

Version < 2.19.0 is compatible with Ruby >= 1.8.7.

### Ruby 2.6.0

> WARNING: Ruby 2.6.0 introduced a new bug ([#15472 -
Invalid JSON data being sent from Net::HTTP in some cases with Ruby 2.6.0](https://bugs.ruby-lang.org/issues/15472)) that may result in the Rollbar API returning an error when an exception is reported.  (See [rollbar-gem issue #797](https://github.com/rollbar/rollbar-gem/issues/797)).

> UPDATE: This bug is fixed in Ruby 2.6.1, and rollbar-gem has a safe workaround in version >= 2.19.0.
If you need to stay on Ruby 2.6.0 for any reason, make sure you have the latest rollbar-gem.

## Release History & Changelog

See our [Releases](https://github.com/rollbar/rollbar-gem/releases) page for a list of all releases, including changes.

## Help / Support

If you run into any issues, please email us at [support@rollbar.com](mailto:support@rollbar.com)

For bug reports, please [open an issue on GitHub](https://github.com/rollbar/rollbar-gem/issues/new).

## Contributing

1. Fork it
2. Create your feature branch (```git checkout -b my-new-feature```).
3. Commit your changes (```git commit -am 'Added some feature'```)
4. Push to the branch (```git push origin my-new-feature```)
5. Create new Pull Request

We're using RSpec for testing. Run the test suite with ```rake spec```. Tests for pull requests are appreciated but not required. (If you don't include a test, we'll write one before merging.)

## License
Rollbar-gem is free software released under the MIT License. See [LICENSE](LICENSE) for details.
