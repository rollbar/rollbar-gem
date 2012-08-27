# Ratchetio

Ruby gem for Ratchet.io, for reporting exceptions in Rails 3 to Ratchet.io. Requires a Ratchet.io account (you can sign up for free).

## Installation

Add this line to your application's Gemfile:

    gem 'ratchetio'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ratchetio

Then, create a file config/initializers/ratchetio.rb containing the following:

```
require 'ratchetio/rails'
Ratchetio.configure do |config|
  config.access_token = 'YOUR_RATCHETIO_PROJECT_ACCESS_TOKEN'
end
```

## Usage

This gem installs an exception handler into Rails. You don't need to do anything else for it to work.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
