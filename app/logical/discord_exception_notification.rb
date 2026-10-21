# frozen_string_literal: true

class DiscordExceptionNotification
  attr_reader(:log)

  def initialize(log)
    @log = log
  end

  def self.webhook_url
    Fennec.config.discord.exceptions_webhook_url
  end

  # the same error repeating only gets sent once every 5 minutes, so a broken page doesn't hit discord's rate limit
  def self.deliver_later(log)
    return if webhook_url.blank?
    return unless Rails.cache.write("exception_webhook:#{log.class_name}:#{log.extra_params['source']}", true, expires_in: 5.minutes, unless_exist: true)
    ExceptionWebhookJob.perform_later(log.id)
  end

  def embed
    {
      color:       DiscordNotification::RED,
      title:       log.class_name.truncate(256),
      description: "```\n#{log.message.truncate(3500)}\n```",
      url:         Rails.application.routes.url_helpers.admin_exception_url(log),
      fields:      [
        { name: "Source", value: log.extra_params["source"].to_s.truncate(1024).presence || "Unknown", inline: true },
        { name: "Host", value: log.extra_params["host"].to_s.presence || "Unknown", inline: true },
        { name: "Version", value: log.version.presence || "Unknown", inline: true },
        { name: "Code", value: log.code },
      ],
      timestamp:   log.created_at.iso8601,
    }
  end

  def execute!
    return if self.class.webhook_url.blank?

    conn = Faraday.new(Fennec.config.faraday_options)
    conn.post(self.class.webhook_url, { embeds: [embed] }.to_json, { content_type: "application/json" })
  end
end
