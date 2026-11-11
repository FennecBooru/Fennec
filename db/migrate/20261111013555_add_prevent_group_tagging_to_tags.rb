# frozen_string_literal: true

class AddPreventGroupTaggingToTags < ActiveRecord::Migration[8.1]
  def change
    add_column(:tags, :prevent_group_tagging, :boolean, default: false, null: false)
    add_column(:tag_versions, :prevent_group_tagging, :boolean, default: false, null: false)
    change_column_default(:tag_versions, :prevent_group_tagging, from: false, to: nil)
  end
end
