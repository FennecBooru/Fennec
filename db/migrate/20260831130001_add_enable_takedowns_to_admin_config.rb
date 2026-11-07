# frozen_string_literal: true

class AddEnableTakedownsToAdminConfig < ActiveRecord::Migration[8.1]
  before { admin_config_override! }
  after { AdminConfig.delete_cache }

  def change
    add_column(:admin_config, :enable_takedowns, :boolean, null: false, default: false)
  end
end
