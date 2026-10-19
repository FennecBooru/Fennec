# frozen_string_literal: true

# Site features that can be turned off in the admin config, each backed by an enable_* column.
# staff_access: features stay usable by staff while off, for ones other things are managed through.
module Feature
  Definition = Struct.new(:name, :column, :staff_access)

  @definitions = {}

  def self.define(name, column: :"enable_#{name}", staff_access: false)
    @definitions[name] = Definition.new(name, column, staff_access)
  end

  def self.find(name)
    @definitions.fetch(name.to_sym) { raise(ArgumentError, "Unknown feature: #{name}") }
  end

  def self.definitions
    @definitions.values
  end

  def self.enabled?(name)
    AdminConfig.public_send(:"#{find(name).column}?")
  end

  # enabled, or off but still usable by staff
  def self.available?(name, user)
    enabled?(name) || (find(name).staff_access && user.is_staff?)
  end

  define(:api_key_usage_tracking)
  define(:api_keys)
  # avoid posting entries and linked uploaders are managed through artists
  define(:artist_pages, staff_access: true)
  define(:avoid_posting)
  define(:character_groups)
  define(:character_pages)
  define(:comments)
  define(:db_exports)
  define(:discord)
  define(:forums)
  define(:mascots)
  define(:notes)
  define(:pools)
  define(:post_appeals)
  define(:post_approvals)
  define(:post_flags)
  define(:post_sets)
  define(:recommendations)
  define(:replacement_approvals)
  define(:reports)
  define(:rules)
  define(:search_tracking)
  define(:tag_following)
  define(:takedowns)
  # staff handle existing tickets and the ones created automatically, like spam reports
  define(:tickets, staff_access: true)
  define(:upload_whitelist)
  define(:user_feedback)
  define(:view_tracking)
  # the static and help pages are wiki pages, staff still need to edit them
  define(:wiki, staff_access: true)
end
