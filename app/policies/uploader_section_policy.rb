# frozen_string_literal: true

class UploaderSectionPolicy < ApplicationPolicy
  def index?
    user.is_admin?
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

  # the kind can only be picked when creating, and only tags sections can be created
  def permitted_attributes_for_create
    super + %i[key]
  end

  def permitted_attributes
    %i[label hint placeholder requirement show_in_compact_mode is_enabled]
  end
end
