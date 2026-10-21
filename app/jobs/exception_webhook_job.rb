# frozen_string_literal: true

class ExceptionWebhookJob < ApplicationJob
  queue_as(:low)

  def perform(exception_log_id)
    log = ExceptionLog.find_by(id: exception_log_id)
    DiscordExceptionNotification.new(log).execute! if log
  end
end
