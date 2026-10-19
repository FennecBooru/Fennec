# frozen_string_literal: true

class TagPolicy < ApplicationPolicy
  def meta_search?
    index?
  end

  def preview?
    member?
  end

  def update?
    return false if record && !record.category_editable_by?(user)
    member?
  end

  def correct?
    user.is_janitor?
  end

  def followed?
    following_enabled? && member?
  end

  def followers?
    following_enabled? && member?
  end

  def follow?
    following_enabled? && member?
  end

  def unfollow?
    following_enabled? && member?
  end

  def permitted_attributes
    attr = %i[category_id reason]
    attr += %i[is_deprecated is_locked] if user.is_admin?
    attr
  end

  def permitted_search_params
    params = super + %i[fuzzy_name_matches name_matches name category_id hide_empty has_wiki has_artist is_locked is_deprecated creator_id creator_name] + nested_search_params(creator: User)
    params << :ip_addr if can_search_ip_addr?
    params
  end

  private

  def following_enabled?
    Feature.enabled?(:tag_following)
  end
end
