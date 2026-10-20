# frozen_string_literal: true

class CreateUploaderSections < ActiveRecord::Migration[8.1]
  with_admin_config_override!

  # admin config column => uploader section key
  PLACEHOLDER_MAP = {
    artist_tag_placeholder:    "artist",
    character_tag_placeholder: "character",
    species_tag_placeholder:   "species",
    content_tag_placeholder:   "content",
  }.freeze
  # admin config column => [uploader section key, the wiki page's default title]
  WIKI_PAGE_MAP = {
    tag_genders_howto_wiki_page: ["character", "howto:tag_genders"],
    tag_what_you_see_wiki_page:  %w[other_tags tag_what_you_see],
  }.freeze

  def change
    create_table(:uploader_sections) do |t|
      t.references(:creator, foreign_key: { to_table: :users }, null: false)
      t.inet(:creator_ip_addr, null: false)
      t.references(:updater, foreign_key: { to_table: :users }, null: false)
      t.inet(:updater_ip_addr, null: false)
      t.string(:kind, null: false)
      t.string(:key, null: false, index: { unique: true })
      t.string(:label, null: false)
      t.text(:hint, null: false, default: "")
      t.string(:placeholder, null: false, default: "")
      t.string(:requirement, null: false, default: "none")
      t.boolean(:show_in_compact_mode, null: false, default: false)
      t.boolean(:is_enabled, null: false, default: true)
      t.integer(:position, null: false)
      t.timestamps
    end
    # deferred so reordering can swap positions within a transaction
    add_unique_constraint(:uploader_sections, :position, deferrable: :deferred, name: "uploader_sections_position_unique")

    create_table(:uploader_buttons) do |t|
      t.references(:section, foreign_key: { to_table: :uploader_sections, on_delete: :cascade }, null: false)
      t.references(:creator, foreign_key: { to_table: :users }, null: false)
      t.inet(:creator_ip_addr, null: false)
      t.references(:updater, foreign_key: { to_table: :users }, null: false)
      t.inet(:updater_ip_addr, null: false)
      t.string(:name, null: false)
      t.string(:tag, null: false, index: { unique: true })
      t.integer(:row, null: false, default: 1)
      t.integer(:position, null: false, default: 0)
      t.string(:shown_when, array: true, null: false, default: [])
      t.string(:shown_when_mode, null: false, default: "any")
      t.timestamps
    end

    add_column(:admin_config, :uploader_minimum_tags, :integer, null: false, default: 4)

    reversible do |r|
      r.up do
        say_with_time("Running fixer and backfilling uploader values from AdminConfig") do
          run_fix!(250)
          PLACEHOLDER_MAP.each { |column, key| backfill_placeholder(column, key) }
          WIKI_PAGE_MAP.each { |column, (key, default)| backfill_wiki_page(column, key, default) }
          PLACEHOLDER_MAP.size + WIKI_PAGE_MAP.size
        end
      end
      # runs after the config columns are re-added and before the tables are dropped
      r.down do
        say_with_time("Restoring AdminConfig placeholders from uploader sections") do
          AdminConfig.reset_column_information
          PLACEHOLDER_MAP.each { |column, key| restore_placeholder(column, key) }
          AdminConfig.delete_cache
          PLACEHOLDER_MAP.size
        end
      end
    end

    remove_column(:admin_config, :artist_tag_placeholder, :string, null: false, default: "artist_name, unknown_artist, anonymous_artist etc.")
    remove_column(:admin_config, :character_tag_placeholder, :string, null: false, default: "character_name solo_focus 1_male 2_females etc.")
    remove_column(:admin_config, :species_tag_placeholder, :string, null: false, default: "bear dragon hyena rat newt etc.")
    remove_column(:admin_config, :content_tag_placeholder, :string, null: false, default: "cub scatplay watersports diaper my_little_pony vore rape hyper etc.")
    remove_column(:admin_config, :tag_genders_howto_wiki_page, :string, null: false, default: "howto:tag_genders")
    remove_column(:admin_config, :tag_what_you_see_wiki_page, :string, null: false, default: "tag_what_you_see")
    up_only { AdminConfig.delete_cache }
  end

  def backfill_placeholder(column, key)
    value = AdminConfig.get[column]
    say("Setting uploader section #{key} placeholder to #{value.inspect} (from #{column})", true)
    UploaderSection.where(key: key).update_all(placeholder: value)
  end

  # the default hints link to the default titles
  def backfill_wiki_page(column, key, default)
    value = AdminConfig.get[column]
    return if value == default
    say("Linking uploader section #{key} hint to #{value.inspect} (from #{column})", true)
    UploaderSection.where(key: key).update_all(["hint = replace(hint, ?, ?)", "[[#{default}|", "[[#{value}|"])
  end

  def restore_placeholder(column, key)
    value = UploaderSection.where(key: key).pick(:placeholder)
    return if value.blank? # keep the column default
    say("Setting #{column} to #{value.inspect} (from uploader section #{key})", true)
    AdminConfig.get.update_column(column, value)
  end
end
