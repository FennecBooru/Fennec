# frozen_string_literal: true

class AddPostFlagNoteMaxSizeToConfig < ActiveRecord::Migration[7.1]
  before { config_override! }
  after { Config.delete_cache }

  def change
    add_column(:config, :post_flag_note_max_size, :integer, default: 10_000, null: false)
  end
end
