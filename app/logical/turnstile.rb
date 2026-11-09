# frozen_string_literal: true

# Checks Cloudflare Turnstile tokens, https://developers.cloudflare.com/turnstile/get-started/server-side-validation/
module Turnstile
  module_function

  VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify"

  def enabled?
    Fennec.config.turnstile.enabled?
  end

  # Whether the widget's token is valid for this site and action. Anything going wrong counts as invalid.
  def verify(token, action:, remote_ip: nil)
    return false unless token.is_a?(String) && token.present? && token.length <= 2048

    params = { secret: Fennec.config.turnstile.secret_key, response: token, remoteip: remote_ip }.compact
    response = Faraday.new(Fennec.config.faraday_options.deep_merge(request: { timeout: 10, open_timeout: 5 })).post(VERIFY_URL, params)
    return false unless response.success?

    result = JSON.parse(response.body)
    # tokens from another site using the same widget, or another form, aren't accepted
    result["success"] == true && result["action"] == action && result["hostname"] == hostname
  rescue Faraday::Error, JSON::ParserError
    false
  end

  def hostname
    URI.parse(Fennec.config.hostname).host
  end
end
