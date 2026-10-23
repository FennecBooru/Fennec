# frozen_string_literal: true

class AddEnableRatingsToAdminConfig < ActiveRecord::Migration[8.1]
  def change
    add_column(:admin_config, :enable_ratings, :boolean, default: true, null: false)
  end
end
