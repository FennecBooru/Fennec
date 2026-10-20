# frozen_string_literal: true

module Users
  class PasswordResetsController < ApplicationController
    requires_email

    def new
      @nonce = UserPasswordResetNonce.new_with_current(:user)
    end

    def edit
      @nonce = UserPasswordResetNonce.find_by(user_id: params[:uid], key: params[:key])
    end

    def create
      ::User.with_email(params[:email]).each do |user|
        next if user.is_moderator?
        UserEvent.create_from_request!(user, :password_reset, request)
        UserPasswordResetNonce.create(user_id: user.id)
      end
      redirect_to(new_users_password_reset_path, notice: "If your email was on file, an email has been sent your way. It should arrive within the next few minutes. Make sure to check your spam folder.")
    end

    def update
      @nonce = UserPasswordResetNonce.find_by(user_id: params[:uid], key: params[:key])

      if @nonce
        if @nonce.expired?
          return redirect_to(new_users_password_reset_path, notice: "Reset expired")
        end
        if @nonce.reset_user!(params[:password], params[:password_confirm])
          @nonce.destroy
          redirect_to(new_users_password_reset_path, notice: "Password reset")
        else
          redirect_to(new_users_password_reset_path, notice: "Passwords do not match")
        end
      else
        redirect_to(new_users_password_reset_path, notice: "Invalid reset token")
      end
    end
  end
end
