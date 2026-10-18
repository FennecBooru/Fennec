# frozen_string_literal: true

class RenameTagCategoryColumnsToCategoryId < ActiveRecord::Migration[8.1]
  def change
    rename_column(:tags, :category, :category_id)
    rename_column(:tag_versions, :category, :category_id)
    # Postgres doesn't rename the NOT NULL constraints along with the columns
    reversible do |dir|
      dir.up do
        rename_constraint_if_exists(:tags, "tags_category_not_null", "tags_category_id_not_null")
        rename_constraint_if_exists(:tag_versions, "tag_versions_category_not_null", "tag_versions_category_id_not_null")
      end
      dir.down do
        rename_constraint_if_exists(:tags, "tags_category_id_not_null", "tags_category_not_null")
        rename_constraint_if_exists(:tag_versions, "tag_versions_category_id_not_null", "tag_versions_category_not_null")
      end
    end
  end
end
