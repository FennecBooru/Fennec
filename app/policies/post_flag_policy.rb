# frozen_string_literal: true

class PostFlagPolicy < ApplicationPolicy
  def create?
    AdminConfig.enable_post_flags? && member? && !user.no_flagging?
  end

  def destroy?
    approver?
  end

  def permitted_attributes
    %i[post_id reason_name parent_id note]
  end

  def permitted_search_params
    # creator_id and creator_name are special cased in the model search function
    params = super + %i[reason_matches creator_id creator_name post_id post_tags_match type is_resolved] + nested_search_params(post: Post)
    params += %i[note_matches] if user.is_staff?
    params += %i[ip_addr] if can_search_ip_addr?
    params
  end

  def api_attributes
    attr = super + %i[type]
    attr -= %i[creator_id] unless user.can_view_flagger_on_post?(record)
    attr
  end
end
