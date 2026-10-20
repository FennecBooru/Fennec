# frozen_string_literal: true

module Users
  class LoginRemindersController < ApplicationController
    requires_email

    def new
    end

    def create
      @user = User.with_email(params.dig(:user, :email)).first
      if @user
        LoginReminderMailer.notice(@user).deliver_now
      end

      flash[:notice] = "If your email was on file, an email has been sent your way. It should arrive within the next few minutes. Make sure to check your spam folder"

      redirect_to(new_users_login_reminder_path)
    end
  end
end
