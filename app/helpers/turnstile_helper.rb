# frozen_string_literal: true

module TurnstileHelper
  def turnstile_tags(action:)
    safe_join([
      javascript_include_tag("https://challenges.cloudflare.com/turnstile/v0/api.js", async: true, defer: true, nonce: true),
      tag.div(class: "cf-turnstile", data: { sitekey: Fennec.config.turnstile.site_key, action: action, theme: "dark" }),
    ])
  end
end
