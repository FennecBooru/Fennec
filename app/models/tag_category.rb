# frozen_string_literal: true

# Every category is optional. Code refers to them by name through TagCategory.<name>, which
# returns the id of the category with that name or alias, or nil when there isn't one.
class TagCategory < ApplicationRecord
  DEFAULTS_FILE = Rails.root.join("db/seeds/tag_categories.yml")
  NAME_REGEX = /\A[a-z]+\z/
  COLOR_REGEX = /\A#(?:\h{3}|\h{4}|\h{6}|\h{8})\z/
  NEVER_MATCH = /(?!)/
  MAX_ID = 32_767 # tags.category_id is a smallint

  # Names the code looks categories up by (TagCategory.artist, tag.artist?, post.artist_tags, etc), and what stops
  # working when no category has the name. test/unit/tag_category_test.rb checks this matches the code
  CODE_REFERENCES = {
    "general"   => "the new general tag hint, the 10 general tags upload warning, deprecating tags, and alias category transfers",
    "artist"    => "artist links, pool artists, avoid posting, the artist tag upload requirement, artist renames, uploader verification, file names, and the artist color in styles",
    "copyright" => "post descriptions and file names",
    "character" => "character groups, post version labels, file names, reupload links, and the character color in styles",
    "species"   => "file names and reupload links",
    "invalid"   => "deprecating tags, the invalid tag warning, and keeping invalid tags out of locked tags and character groups",
    "meta"      => "keeping meta tags out of character groups and the repopulated tag warning",
  }.freeze

  belongs_to_user(:creator, ip: true, clones: :updater)
  belongs_to_user(:updater, ip: true)
  has_many(:tags, foreign_key: :category_id, inverse_of: :category, dependent: nil)
  resolvable(:destroyer)
  attr_accessor(:new_category_id) # for the transfer tags form

  array_attribute(:aliases, parse: /[^\s,]+/, join_character: " ")
  array_attribute(:suffixes, parse: /[^\s,]+/, join_character: " ")
  array_attribute(:format_exclusion, parse: /[^\s,]+/, join_character: " ")

  normalizes(:name, with: ->(name) { name.to_s.strip.downcase })
  normalizes(:aliases, with: ->(aliases) { aliases.map { |a| a.to_s.strip.downcase }.compact_blank.uniq })
  normalizes(:suffixes, with: ->(suffixes) { suffixes.map(&:strip).compact_blank.uniq })
  normalizes(:format_exclusion, with: ->(tags) { tags.map { |tag| Tag.normalize_name(tag) }.compact_blank.uniq })
  normalizes(:color, :color_alt, with: ->(color) { color.to_s.strip.downcase })

  validates(:name, presence: true, format: { with: NAME_REGEX, message: "can only contain lowercase letters" })
  validates(:header, :display, presence: true, length: { maximum: 100 })
  validates(:color, :color_alt, format: { with: COLOR_REGEX, message: "must be a hex color, like #a1b2c3" })
  validates(:format_limit, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true)
  validates(:position, numericality: { only_integer: true }, uniqueness: true, unless: :is_deleted?)
  validates(:min_level, inclusion: { in: ->(_) { User::Levels.hash.values } })
  validates(:format_position, numericality: { only_integer: true }, allow_nil: true)
  validate(:validate_names)
  validate(:validate_format)
  validate(:validate_default, on: :update)
  validate(:validate_id, on: :create)

  before_validation(:set_display_defaults)
  before_validation(:assign_position, on: :create)
  before_validation(:keep_old_name_as_alias, on: :update, if: :name_changed?)
  before_save(:unset_other_defaults, if: -> { is_default? && is_default_changed? })
  before_create(:assign_id)
  before_destroy(:validate_deletable, prepend: true)
  after_commit(-> { TagCategory.clear_cache })

  # deleted categories are left out everywhere but id checks, see #remove
  scope(:active, -> { where(is_deleted: false) })
  scope(:deleted, -> { where(is_deleted: true) })

  modactions(:tag_category)
    .add(:create, :creator, on: :create) { { name: name } }
    .add(:update, :updater, on: :update) { { name: name, old_name: name_before_last_save } }
    .add(:delete, :destroyer, on: :destroy) { { name: name } }

  module RegistryMethods
    # Cached rows, as instantiated read only records ordered by position
    def categories
      RequestStore.store[:tag_categories] ||= cached_rows.map { |row| instantiate(row).tap(&:readonly!) }
    end

    def cached_rows
      RequestStore.store[:tag_category_rows] ||= Cache.fetch("tag_categories", expires_in: 1.hour) do
        connection.select_all(unscoped.active.order(:position, :id).to_sql).to_a
      end
    end

    def clear_cache
      Cache.delete("tag_categories")
      RequestStore.store.delete(:tag_categories)
      RequestStore.store.delete(:tag_category_rows)
      RequestStore.store.delete(:tag_category_lookups)
    end

    # Changes whenever any category does, used to bust the stylesheet cache
    def version
      lookups[:version] ||= Digest::MD5.hexdigest(cached_rows.to_json)[0, 12]
    end

    # Accepts an id, a name or alias, or a category
    def get(value)
      case value
      when TagCategory then value
      when Integer then lookups[:by_id][value]
      when nil then nil
      else lookups[:by_value][value.to_s.downcase]
      end
    end

    def default
      lookups[:default]
    end

    # Shown in place of a category that's been deleted, like in tag history
    def deleted_name(id)
      "Deleted Category (#{id})"
    end

    def default_id
      default&.id
    end

    def ids
      lookups[:ids]
    end

    def category_names
      lookups[:names]
    end

    # { name or alias => id }
    def mapping
      lookups[:mapping]
    end

    # { id => name }
    def reverse_mapping
      lookups[:reverse_mapping]
    end

    def for_select
      categories.map { |c| [c.display, c.id] }
    end

    # The id for a name or alias, or the default category's id
    def value_for(string)
      mapping[string.to_s.downcase] || default_id
    end

    # Matches any name or alias, used for prefixes like "char:"
    def regexp
      lookups[:regexp] ||= regexp_for(mapping.keys)
    end

    # The short names used for metatags like "chartags", { short name => name }
    def short_name_mapping
      lookups[:short_name_mapping] ||= categories.flat_map { |c| (c.aliases.presence || [c.name]).map { |a| [a, c.name] } }.to_h
    end

    def short_name_list
      short_name_mapping.keys
    end

    def short_name_regex
      lookups[:short_name_regex] ||= regexp_for(short_name_list).source
    end

    # The categories used to build a post's description, like "character (copyright) created by artist"
    def formatted
      lookups[:formatted] ||= categories.select(&:format_position).sort_by { |c| [c.format_position, c.id] }
    end

    def as_frontend_json
      {
        categories:  categories.map { |c| c.slice(:id, :name, :aliases, :header, :display) },
        mapping:     mapping,
        short_names: short_name_list,
        default_id:  default_id,
      }
    end

    # Creates any of the categories from DEFAULTS_FILE that don't exist yet
    def create_defaults!(creator_id: User.system.id, creator_ip_addr: "127.0.0.1")
      now = Time.current
      rows = YAML.load_file(DEFAULTS_FILE).map do |row|
        row = row.symbolize_keys
        {
          header:          row[:name].titlecase,
          display:         row[:name].titlecase,
          creator_id:      creator_id,
          creator_ip_addr: creator_ip_addr,
          updater_id:      creator_id,
          updater_ip_addr: creator_ip_addr,
          created_at:      now,
          updated_at:      now,
          **row,
        }
      end
      rows.reject! { |row| exists?(id: row[:id]) || exists?(name: row[:name]) }
      # insert_all needs every row to have the same keys, missing ones would be null instead of the column default
      keys = rows.flat_map(&:keys).uniq
      insert_all!(rows.map { |row| keys.index_with { |key| row.fetch(key) { column_defaults[key.to_s] } } }) if rows.any?
      # it's still tags.category while 20261014031322 runs, it's renamed after
      column = connection.column_exists?(:tags, :category_id) ? "category_id" : "category"
      connection.execute("UPDATE tag_categories SET tag_count = (SELECT COUNT(*) FROM tags WHERE tags.#{column} = tag_categories.id)")
      clear_cache
    end

    # TagCategory.artist etc, the id of the category with that name or alias, or nil
    def method_missing(name, *args, &)
      return super unless args.empty? && !block_given? && name.match?(NAME_REGEX)
      get(name.to_s)&.id
    end

    def respond_to_missing?(name, include_private = false)
      (name.match?(NAME_REGEX) && get(name.to_s).present?) || super
    end

    private

    def lookups
      RequestStore.store[:tag_category_lookups] ||= begin
        list = categories
        mapping = list.flat_map { |c| c.values.map { |v| [v, c.id] } }.to_h
        {
          by_id:           list.index_by(&:id),
          by_value:        list.flat_map { |c| c.values.map { |v| [v, c] } }.to_h,
          default:         list.find(&:is_default?),
          ids:             list.map(&:id),
          names:           list.map(&:name),
          mapping:         mapping,
          reverse_mapping: list.to_h { |c| [c.id, c.name] },
        }
      end
    end

    def regexp_for(values)
      return NEVER_MATCH if values.empty?
      Regexp.union(values.sort_by { |v| -v.length })
    end
  end

  extend(RegistryMethods)

  module SearchMethods
    def query_dsl
      super
        .field(:name)
        .field(:is_default)
        .field(:min_level)
        .association(:creator)
        .association(:updater)
    end

    # deleted is excluded, included, or only. Only admins can search for it, see TagCategoryPolicy
    def search(params, user)
      q = super

      deleted = (params[:deleted].presence || "excluded").downcase
      q = q.active if deleted == "excluded"
      q = q.deleted if deleted == "only"
      q
    end

    def apply_order(params)
      order_with({
        position: { "tag_categories.position": :asc, "tag_categories.id": :asc },
        name:     { "tag_categories.name": :asc },
      }, params[:order] || "position")
    end
  end

  extend(SearchMethods)

  def values
    [name, *aliases]
  end

  def title
    name.titleize
  end

  def can_use?(user)
    user.is_system? || user.level >= min_level
  end

  def format_regexp
    @format_regexp ||= Regexp.new(format_regex) if format_regex.present?
  end

  # The code references this category holds, { name => what uses it }
  def code_references
    CODE_REFERENCES.slice(*values)
  end

  # The code references the last save took away, which no category has anymore
  def removed_code_references
    old_values = [name_before_last_save, *aliases_before_last_save].compact
    CODE_REFERENCES.slice(*(old_values - values))
  end

  # The code references no category has
  def self.missing_code_references
    CODE_REFERENCES.except(*mapping.keys)
  end

  # Moves every tag into another category in the background, so this one can be deleted
  def transfer_tags(new_category, user)
    TransferTagCategoryTagsJob.perform_later(user, self, new_category)
  end

  # posts are updated by a job after their tags change category, so they're checked too
  def posts_counted?
    Post.exists?(["jsonb_exists(tag_category_data, ?)", id.to_s])
  end

  def deletable?
    !is_default? && !Tag.exists?(category_id: id)
  end

  # Tag versions and posts that still count it have the id
  def had_tags?
    TagVersion.exists?(category_id: id) || posts_counted?
  end

  # Deletes the category, or for ones that had tags marks it deleted and locks it, so the id stays taken.
  # Either way it's gone everywhere but id checks
  def remove(user)
    self.destroyer = user
    return destroy unless had_tags?
    return false unless validate_deletable(abort: false)

    update_columns(is_deleted: true, min_level: User::Levels::LOCKED, is_default: false, position: nil, updated_at: Time.current)
    TagCategory.clear_cache
    log_delete
    true
  end

  def self.log_reorder(changes, user)
    ModAction.log!(user, :tag_categories_reorder, nil, total: changes)
  end

  def self.available_includes
    %i[creator updater]
  end

  private

  def set_display_defaults
    return if name.blank?
    self.header = name.titlecase if header.blank?
    self.display = name.titlecase if display.blank?
  end

  # Keeps searches and tag prefixes using the old name working
  def keep_old_name_as_alias
    return if name_was.blank?
    self.aliases = (aliases + [name_was]).uniq - [name]
  end

  # new categories go at the end, so nothing else has to move
  def assign_position
    self.position ||= (TagCategory.unscoped.maximum(:position) || -1) + 1
  end

  # Ids aren't reused, so this skips ids that tags have had, including deleted categories'
  def assign_id
    self.id ||= [TagCategory.unscoped.maximum(:id), Tag.maximum(:category_id), TagVersion.maximum(:category_id)].compact.max.to_i + 1
    return if id <= MAX_ID
    errors.add(:id, "would be past #{MAX_ID}, pick an unused one")
    throw(:abort)
  end

  def unset_other_defaults
    TagCategory.active.where.not(id: id).where(is_default: true).update_all(is_default: false)
  end

  def validate_names
    errors.add(:aliases, "can't include the name") if aliases.include?(name)
    aliases.each do |value|
      errors.add(:aliases, "#{value} can only contain lowercase letters") unless value.match?(NAME_REGEX)
    end

    others = TagCategory.active.where.not(id: id)
    taken = others.where(name: values).or(others.where("aliases && ARRAY[?]::varchar[]", values)).flat_map(&:values) & values
    errors.add(:base, "#{taken.to_sentence} #{taken.one? ? 'is' : 'are'} already used by another category") if taken.any?

    added = values - (persisted? ? [name_was, *aliases_was].compact : [])
    added.each do |value|
      if TagQuery::METATAGS.include?(value) || TagQuery::METATAGS.include?("#{value}tags")
        errors.add(:base, "#{value} is already used by a metatag")
      elsif TagCategory.methods.include?(value.to_sym) || Tag.method_defined?(:"#{value}?") || Post.method_defined?(:"#{value}_tags")
        errors.add(:base, "#{value} is reserved")
      elsif Tag.exists?(["name LIKE ?", "#{Tag.sanitize_sql_like(value)}:%"])
        errors.add(:base, "#{value} can't be used while tags starting with \"#{value}:\" exist")
      end
    end
  end

  def validate_format
    errors.add(:format_string, "must include %s once") if format_string.present? && format_string.scan("%s").size != 1
    return if format_regex.blank?
    # the empty alternative always matches, which shows how many groups there are
    errors.add(:format_regex, "must have a capture group") if Regexp.new("#{format_regex}|").match("").size < 2
  rescue RegexpError => e
    errors.add(:format_regex, "is invalid: #{e.message}")
  end

  # ids are stored on tags and posts, so a given one has to be unused, and never have had tags
  def validate_id
    return if id.nil?
    if !id.is_a?(Integer) || id < 0 || id > MAX_ID
      errors.add(:id, "must be a whole number from 0 to #{MAX_ID}")
    elsif TagCategory.exists?(id: id)
      errors.add(:id, "is already used by another category, or a deleted one")
    elsif Tag.exists?(category_id: id) || TagVersion.exists?(category_id: id)
      errors.add(:id, "has had tags before, so it can't be reused")
    end
  end

  def validate_default
    errors.add(:is_default, "can't be removed, make another category the default instead") if is_default_was && !is_default?
  end

  def validate_deletable(abort: true)
    if is_default?
      errors.add(:base, "The default category can't be deleted")
    elsif Tag.exists?(category_id: id)
      errors.add(:base, "Move the category's tags to another one before deleting it")
    end
    throw(:abort) if abort && errors.any?
    errors.empty?
  end
end
