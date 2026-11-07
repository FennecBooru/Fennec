# frozen_string_literal: true

class AddFlagAiPostsToConfig < ActiveRecord::Migration[7.1]
  before { config_override! }
  after { Config.delete_cache }

  def change
    add_column(:config, :flag_ai_posts, :boolean, null: false, default: true)
    add_column(:config, :tag_ai_posts, :boolean, null: false, default: true)
    add_column(:config, :ai_confidence_threshold, :integer, null: false, default: 50)
  end
end
