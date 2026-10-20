# frozen_string_literal: true

Recaptcha.configure do |config|
  config.site_key   = Fennec.config.recaptcha.site_key
  config.secret_key = Fennec.config.recaptcha.secret_key
  # config.proxy = "http://example.com"
end
