# frozen_string_literal: true

class UserPresenterPolicy < ApplicationPolicy
  attr_reader(:presenter)

  def initialize(user, record)
    @presenter = record
    @record = record.user
    @user = user
  end

  def show_approvals?
    record.can_approve_posts? || Post.exists?(approver: record)
  end

  def show_flags?
    user.is_janitor? || user == record
  end

  def show_tickets?
    user.is_moderator? || (Feature.enabled?(:tickets) && user == record)
  end

  def show_api_keys?
    Feature.enabled?(:api_keys) && (user.is_owner? || user == record)
  end

  def show_email?
    policy(user).can_see_email?
  end
end
