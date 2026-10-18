# frozen_string_literal: true

class MakeTagCategoriesDynamic < ActiveRecord::Migration[8.1]
  with_admin_config_override!

  ID_MAP = {
    0  => "general",
    1  => "artist",
    2  => "contributor",
    3  => "copyright",
    4  => "character",
    5  => "species",
    6  => "invalid",
    7  => "meta",
    8  => "lore",
    9  => "gender",
    10 => "important",
  }.freeze
  # admin config column => [tag category id, tag category column]
  CONFIG_MAP = {
    artist_exclusion_tags: [1, :format_exclusion],
    contributor_suffixes:  [2, :suffixes],
    lore_suffixes:         [8, :suffixes],
  }.freeze

  def change
    add_column(:posts, :tag_category_data, :jsonb, null: false, default: {})
    update_change_seq(add: %w[tag_category_data], remove: ID_MAP.values.map { |name| "tag_count_#{name}" })

    %i[general artist contributor character copyright meta species invalid lore gender important].each do |name|
      remove_column(:posts, "tag_count_#{name}", :integer, null: false, default: 0)
    end

    create_table(:tag_categories, id: :integer, default: nil) do |t|
      t.references(:creator, foreign_key: { to_table: :users }, null: false)
      t.inet(:creator_ip_addr, null: false)
      t.references(:updater, foreign_key: { to_table: :users }, null: false)
      t.inet(:updater_ip_addr, null: false)
      t.string(:name, null: false)
      t.string(:aliases, array: true, null: false, default: [])
      t.string(:header, null: false)
      t.string(:display, null: false)
      t.string(:color, null: false)
      t.string(:color_alt, null: false)
      t.integer(:format_limit)
      t.string(:format_string)
      t.string(:format_exclusion, array: true, null: false, default: [])
      t.string(:format_regex)
      t.string(:suffixes, array: true, null: false, default: [])
      t.integer(:format_position)
      t.integer(:position) # null for deleted categories
      t.integer(:min_level, null: false, default: 0) # User::Levels::ANONYMOUS
      t.boolean(:is_default, null: false, default: false)
      t.boolean(:is_deleted, null: false, default: false)
      t.integer(:tag_count, null: false, default: 0)
      t.timestamps
      # deleted categories' names can be reused
      t.index("lower(name)", unique: true, where: "NOT is_deleted")
      t.index(:is_default, unique: true, where: "is_default")
    end
    # deferred so reordering can swap positions within a transaction
    add_unique_constraint(:tag_categories, :position, deferrable: :deferred, name: "tag_categories_position_unique")
    # new tags get the default category instead
    change_column_default(:tags, :category, from: 0, to: nil)

    reversible do |r|
      r.up do
        say_with_time("Running fixer and backfilling AdminConfig values") do
          run_fix!(246)
          CONFIG_MAP.each { |key, (id, column)| backfill_category(id, column, key) }
          CONFIG_MAP.size # number of updates
        end
      end
      # runs after the config columns are re-added and before tag_categories is dropped
      r.down do
        say_with_time("Restoring AdminConfig values from tag categories") do
          AdminConfig.reset_column_information
          CONFIG_MAP.each { |key, (id, column)| restore_config(id, column, key) }
          AdminConfig.delete_cache
          CONFIG_MAP.size
        end
      end
    end

    remove_column(:admin_config, :artist_exclusion_tags, :text, null: false, default: "avoid_posting, conditional_dnp, epilepsy_warning, sound_warning")
    remove_column(:admin_config, :contributor_suffixes, :text, null: false, default: "va, modeler")
    remove_column(:admin_config, :lore_suffixes, :text, null: false, default: "lore")
    up_only { AdminConfig.delete_cache }
  end

  def backfill_category(id, column, key)
    value = AdminConfig.get[key].split(",").map(&:strip)
    say("Setting tag category #{id} #{column} to #{value.inspect} (from #{key})", true)
    TagCategory.where(id: id).update_all(column => value)
  end

  def restore_config(id, column, key)
    value = TagCategory.where(id: id).pick(column)
    return if value.nil? # keep the column default
    say("Setting #{key} to #{value.join(', ').inspect} (from tag category #{id} #{column})", true)
    AdminConfig.get.update_column(key, value.join(", "))
  end
end
