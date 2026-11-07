# frozen_string_literal: true

class RenameConfigToAdminConfig < ActiveRecord::Migration[8.1]
  before { admin_config_override! }
  after { AdminConfig.delete_cache }

  def change
    rename_table(:config, :admin_config)
  end
end
