# frozen_string_literal: true

class AddBlacklistedTagsToConfig < ActiveRecord::Migration[7.1]
  before { config_override! }
  after { Config.delete_cache }

  def change
    add_column(:config, :default_blacklist, :string, null: false, default: "")
    add_column(:config, :safeblocked_tags, :string, null: false, default: "")
  end
end
