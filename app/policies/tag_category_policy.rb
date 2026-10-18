# frozen_string_literal: true

class TagCategoryPolicy < ApplicationPolicy
  def styles?
    true
  end

  def create?
    user.is_admin?
  end

  def update?
    user.is_admin?
  end

  def destroy?
    user.is_admin?
  end

  def reorder?
    user.is_admin?
  end

  def show_deleted?
    user.is_admin?
  end

  def transfer_tags?
    user.is_admin?
  end

  def permitted_attributes_for_transfer_tags
    %i[new_category_id]
  end

  # the id can only be picked when creating
  def permitted_attributes_for_create
    super + %i[id]
  end

  def permitted_attributes
    %i[name aliases_string header display color color_alt min_level is_default suffixes_string format_position format_limit format_string format_regex format_exclusion_string]
  end

  def permitted_search_params
    params = super + %i[name is_default min_level creator_id creator_name updater_id updater_name] + nested_search_params(creator: User, updater: User)
    params += %i[deleted] if show_deleted?
    params
  end
end
