# frozen_string_literal: true

class UploaderButtonPolicy < ApplicationPolicy
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

  def permitted_attributes
    %i[name tag row shown_when_string shown_when_mode]
  end
end
