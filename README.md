# Rollbar-gem
[![Build Status](https://api.travis-ci.org/rollbar/rollbar-gem.svg?branch=master)](https://travis-ci.org/rollbar/rollbar-gem/branches)
[![Gem Version](https://badge.fury.io/rb/rollbar.svg)](http://badge.fury.io/rb/rollbar)
[![SemVer](https://api.dependabot.com/badges/compatibility_score?dependency-name=rollbar&package-manager=bundler&version-scheme=semver&target-version=latest)](https://dependabot.com/compatibility-score.html?dependency-name=rollbar&package-manager=bundler&version-scheme=semver&new-version=latest)

> WARNING: Ruby 2.6.0 introduced a new bug bug ([#15472 -
Invalid JSON data being sent from Net::HTTP in some cases with Ruby 2.6.0](https://bugs.ruby-lang.org/issues/15472)) that may result in the Rollbar API returning an error when an exception is reported.  (See [rollbar-gem issue #797](https://github.com/rollbar/rollbar-gem/issues/797)).
> Until the Ruby maintainers have released the fix for this bug, we advise Rollbar users to not upgrade their applications to Ruby 2.6.0.



[Rollbar](https://rollbar.com) is a real-time exception reporting service for Ruby and other languages. The Rollbar service will alert you of problems with your code and help you understand them in a ways never possible before. We love it and we hope you will too.

Rollbar-gem is the SDK for Ruby apps and includes support for apps using Rails, Sinatra, Rack, plain Ruby, and other frameworks.

## Setup Instructions

1. [Sign up for a Rollbar account](https://rollbar.com/signup)
2. Follow the [Getting Started](https://docs.rollbar.com/docs/ruby#section-getting-started) instructions in our [Ruby SDK docs](https://docs.rollbar.com/docs/ruby) to install rollbar-gem and configure it for your platform.

## Usage and Reference

For complete usage instructions and configuration reference, see our [Ruby SDK docs](https://docs.rollbar.com/docs/ruby).

## Compatibility

Version x.x is compatible with Ruby >= 1.9.3.

Version < x.x is compatible with Ruby >= 1.8.7.

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
