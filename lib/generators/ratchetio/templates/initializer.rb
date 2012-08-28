require 'ratchetio/rails'
Ratchetio.configure do |config|
  config.access_token = <%= access_token_expr %>
end
