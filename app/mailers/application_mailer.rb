# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  before_deliver { throw(:abort) unless Fennec.config.enable_email? }
end
