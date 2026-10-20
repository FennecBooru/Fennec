# frozen_string_literal: true

Mailgun.configure do |config|
  config.api_key = Fennec.config.email_mailgun_api_key
end
