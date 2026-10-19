# frozen_string_literal: true

class PostDisapprovalPolicy < ApplicationPolicy
  def index?
    approver?
  end

  def create?
    AdminConfig.enable_post_approvals? && approver?
  end

  def permitted_attributes
    %i[post_id reason message]
  end

  def permitted_search_params
    params = super + %i[creator_id creator_name post_id message post_tags_match reason has_message] + nested_search_params(creator: User)
    params << :ip_addr if can_search_ip_addr?
    params
  end
end
