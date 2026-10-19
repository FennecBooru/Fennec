# frozen_string_literal: true

class PostAppealPolicy < ApplicationPolicy
  def create?
    Feature.enabled?(:post_appeals) && super
  end

  def destroy?
    approver? && (!record.is_a?(PostAppeal) || record.pending?)
  end

  def permitted_search_params
    params = super + %i[reason_matches creator_id creator_name updater_id updater_name post_id post_tags_match status] + nested_search_params(creator: User, updater: User, post: Post)
    params += %i[ip_addr updater_ip_addr] if can_search_ip_addr?
    params
  end

  def permitted_attributes_for_create
    %i[post_id reason]
  end

  def permitted_attributes_for_update
    %i[reason]
  end
end
