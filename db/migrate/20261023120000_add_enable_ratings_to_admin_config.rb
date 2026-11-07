# frozen_string_literal: true

class AddEnableRatingsToAdminConfig < ActiveRecord::Migration[8.1]
  before { admin_config_override! }
  after { AdminConfig.delete_cache }

  def change
    add_column(:admin_config, :enable_ratings, :boolean, default: true, null: false)
  end
end
