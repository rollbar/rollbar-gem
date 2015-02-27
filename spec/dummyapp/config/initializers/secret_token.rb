# Be sure to restart your server when you modify this file.

# Your secret key for verifying the integrity of signed cookies.
# If you change this key, all old signed cookies will become invalid!
# Make sure the secret is at least 30 characters and all random,
# no regular words or you'll be exposed to dictionary attacks.

unless ::Rails::VERSION::STRING.starts_with? "4.2"
  Dummy::Application.config.secret_token = '61f244779bab3ceba188492a31fb02b0a975fb64b93e217c03966ef065f5f1aba3b145c165defe0f8256e45cc6c526a60c9780a506a16e730815a3f812b5f9e9'
end
