# frozen_string_literal: true

class AddArtistFeatureTogglesToAdminConfig < ActiveRecord::Migration[8.1]
  def change
    add_column(:admin_config, :enable_pool_artists, :boolean, default: true, null: false)
    add_column(:admin_config, :enable_uploader_verification, :boolean, default: true, null: false)
  end
end
