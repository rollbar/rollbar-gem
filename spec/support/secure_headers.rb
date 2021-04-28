if defined?(::SecureHeaders)
  # Set a default config if SecureHeaders is present,
  # else it will raise an exception.
  ::SecureHeaders::Configuration.default do |config|
    config.csp = SecureHeaders::OPT_OUT
    config.hsts = SecureHeaders::OPT_OUT
    config.x_frame_options = SecureHeaders::OPT_OUT
    config.x_content_type_options = SecureHeaders::OPT_OUT
    config.x_xss_protection = SecureHeaders::OPT_OUT
    config.x_permitted_cross_domain_policies = SecureHeaders::OPT_OUT
  end
end
