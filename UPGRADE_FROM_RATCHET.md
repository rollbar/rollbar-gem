# Upgrading from ratchetio-gem

## Required immediate steps

Add this line to your application's Gemfile:

    gem 'rollbar', '~> 0.10.3'

And remove:

    gem 'ratchetio'
    
Then execute:

    $ bundle install
    
Next, rename your `config/initializers/ratchetio.rb` to `config/initializers/rollbar.rb`

Open `config/initializers/rollbar.rb` and change `require 'ratchetio/rails'` to `require 'rollbar/rails'`

At this point the new Rollbar library should be properly integrated and begin to report exceptions to Rollbar.

## Optional steps

These are not required because aliases have been set up from the Ratchetio module/functions to the respective Rollbar versions.

Replace all instances of `Ratchetio` in your rails app with `Rollbar`.

Replace all instances of `ratchetio_request_data` with `rollbar_request_data`.

Replace all instances of `ratchetio_person_data` with `rollbar_person_data`.
