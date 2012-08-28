# Ratchetio

Ruby gem for Ratchet.io, for reporting exceptions in Rails 3 to Ratchet.io. Requires a Ratchet.io account (you can sign up for free).

## Installation

Add this line to your application's Gemfile:

    gem 'ratchetio'

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install ratchetio

Then, run the following command from your rails root:

    $ rails generate ratchetio YOUR_RATCHETIO_PROJECT_ACCESS_TOKEN

That will create the file `config/initializers/ratchetio.rb`, which holds the configuration values (currently just your access token) and is all you need to use Ratchet.io with Rails.

## Help / Support

If you run into any issues, please email me at brian@ratchet.io


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
