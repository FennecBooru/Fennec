# frozen_string_literal: true

class EmailsController < ApplicationController
  respond_to(:html)
  requires_email

  def resend_confirmation
    if IpBan.is_banned?(CurrentUser.ip_addr)
      redirect_to(home_users_path, notice: "An error occurred trying to send an activation email")
      return
    end

    raise(User::PrivilegeError, "Must be logged in to resend verification email.") if CurrentUser.user.is_anonymous?
    raise(User::PrivilegeError, "Account already active.") if CurrentUser.user.is_verified?
    raise(User::PrivilegeError, "Cannot send confirmation because the email is not allowed.") if EmailBlacklist.is_banned?(CurrentUser.user.email)
    if RateLimiter.check_limit("emailconfirm:#{CurrentUser.user.id}", 1, 10.minutes)
      raise(User::PrivilegeError, "Confirmation email sent too recently. Please wait at least 10 minutes between sends.")
    end
    RateLimiter.hit("emailconfirm:#{CurrentUser.user.id}", 10.minutes)

    Users::EmailConfirmationMailer.confirmation(CurrentUser.user).deliver_now
    redirect_to(home_users_path, notice: "Activation email resent")
  end

  def activate_user
    if IpBan.is_banned?(CurrentUser.ip_addr)
      redirect_to(home_users_path, notice: "An error occurred trying to activate your account")
      return
    end

    user = verify_get_user(:activate)
    raise(User::PrivilegeError, "Account cannot be activated because the email is not allowed.") if EmailBlacklist.is_banned?(user.email)
    raise(User::PrivilegeError, "Account already activated.") if user.is_verified?

    user.mark_verified!(CurrentUser.user)
    UserEvent.create_from_request!(user, :email_verify, request)

    redirect_to(home_users_path, notice: "Account activated")
  end

  private

  def verify_get_user(purpose)
    message = EmailLinkValidator.validate(params[:sig], purpose)
    raise(User::PrivilegeError, "Invalid activation link.") if message.blank? || !message
    User.find(message.to_i)
  end
end
