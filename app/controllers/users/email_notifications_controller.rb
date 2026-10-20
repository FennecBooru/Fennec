# frozen_string_literal: true

module Users
  class EmailNotificationsController < ApplicationController
    requires_email

    def show
    end

    def destroy
      message = EmailLinkValidator.validate(params[:sig], :unsubscribe)
      if message.blank? || !message || message != params[:user_id].to_s
        return access_denied
      end

      @user = User.find(params[:user_id])
      @user.update(receive_email_notifications: false)
    end
  end
end
