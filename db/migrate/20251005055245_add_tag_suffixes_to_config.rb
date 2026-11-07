# frozen_string_literal: true

class AddTagSuffixesToConfig < ActiveRecord::Migration[7.1]
  before { config_override! }
  after { Config.delete_cache }

  def change
    add_column(:config, :lore_suffixes, :text, default: "lore", null: false)
    add_column(:config, :artist_exclusion_tags, :text, default: "avoid_posting, conditional_dnp, epilepsy_warning, sound_warning", null: false)
  end
end
