# frozen_string_literal: true

class AddFeatureTogglesToAdminConfig < ActiveRecord::Migration[8.1]
  def change
    add_column(:admin_config, :enable_recommendations, :boolean, default: true, null: false)
    add_column(:admin_config, :enable_avoid_posting, :boolean, default: true, null: false)
    add_column(:admin_config, :enable_tag_following, :boolean, default: true, null: false)
    add_column(:admin_config, :enable_reports, :boolean, default: true, null: false)
    add_column(:admin_config, :enable_view_tracking, :boolean, default: true, null: false)
    add_column(:admin_config, :enable_search_tracking, :boolean, default: true, null: false)
    add_column(:admin_config, :enable_api_key_usage_tracking, :boolean, default: true, null: false)
    add_column(:admin_config, :enable_post_approvals, :boolean, default: true, null: false)
    add_column(:admin_config, :enable_post_appeals, :boolean, default: true, null: false)
    add_column(:admin_config, :enable_replacement_approvals, :boolean, default: true, null: false)
    add_column(:admin_config, :enable_rules, :boolean, default: true, null: false)
    add_column(:admin_config, :enable_user_feedback, :boolean, default: true, null: false)
    add_column(:admin_config, :enable_discord, :boolean, default: true, null: false)
    add_column(:admin_config, :enable_forums, :boolean, default: true, null: false)
    add_column(:admin_config, :enable_pools, :boolean, default: true, null: false)
    add_column(:admin_config, :enable_post_sets, :boolean, default: true, null: false)
    add_column(:admin_config, :enable_wiki, :boolean, default: true, null: false)
    add_column(:admin_config, :enable_comments, :boolean, default: true, null: false)
    add_column(:admin_config, :enable_artist_pages, :boolean, default: true, null: false)
    add_column(:admin_config, :enable_character_pages, :boolean, default: true, null: false)
    add_column(:admin_config, :enable_character_groups, :boolean, default: true, null: false)
    add_column(:admin_config, :enable_notes, :boolean, default: true, null: false)
    add_column(:admin_config, :enable_api_keys, :boolean, default: true, null: false)
    add_column(:admin_config, :enable_upload_whitelist, :boolean, default: true, null: false)
    add_column(:admin_config, :enable_mascots, :boolean, default: true, null: false)
    add_column(:admin_config, :enable_tickets, :boolean, default: true, null: false)
    add_column(:admin_config, :enable_post_flags, :boolean, default: true, null: false)
    rename_column(:admin_config, :db_exports_enabled, :enable_db_exports)
  end
end
