# frozen_string_literal: true

class AddExceptionLogRetentionToAdminConfig < ActiveRecord::Migration[8.1]
  def change
    add_column(:admin_config, :exception_log_retention, :integer, default: 0, null: false)
  end
end
