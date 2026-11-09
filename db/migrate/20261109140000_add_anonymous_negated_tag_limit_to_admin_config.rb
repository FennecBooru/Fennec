# frozen_string_literal: true

class AddAnonymousNegatedTagLimitToAdminConfig < ActiveRecord::Migration[8.1]
  before { admin_config_override! }
  after { AdminConfig.delete_cache }

  def change
    add_column(:admin_config, :anonymous_negated_tag_limit, :integer, default: -1, null: false)
  end
end
