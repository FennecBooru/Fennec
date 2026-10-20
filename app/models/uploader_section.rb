# frozen_string_literal: true

# A section of the uploader. Built in sections have their own behavior and are only placed, labeled, and turned on or
# off here. Tags sections are a textarea of tags and rows of buttons, see UploaderButton.
class UploaderSection < ApplicationRecord
  DEFAULTS_FILE = Rails.root.join("db/seeds/uploader_layout.yml")
  BUILTIN_KINDS = %w[file sources rating other_tags character_groups parent locked_tags lock_rating description upload_options].freeze
  # the uploader doesn't work without these
  REQUIRED_KINDS = %w[file rating other_tags].freeze
  KINDS = [*BUILTIN_KINDS, "tags"].freeze
  REQUIREMENTS = %w[none always in_progress].freeze
  KEY_REGEX = /\A[a-z_]+\z/

  belongs_to_user(:creator, ip: true, clones: :updater)
  belongs_to_user(:updater, ip: true)
  # the foreign key deletes them, so deleting a section doesn't log every button
  has_many(:buttons, -> { order(:row, :position, :id) }, class_name: "UploaderButton", foreign_key: :section_id, inverse_of: :section, dependent: nil)
  resolvable(:destroyer)

  normalizes(:key, with: ->(key) { key.to_s.strip.downcase })
  normalizes(:label, :placeholder, with: ->(value) { value.to_s.strip })

  validates(:kind, inclusion: { in: KINDS })
  validates(:key, presence: true, uniqueness: true, format: { with: KEY_REGEX, message: "can only contain lowercase letters and underscores" })
  validates(:label, presence: true, length: { maximum: 100 })
  validates(:hint, length: { maximum: 10_000 })
  validates(:placeholder, length: { maximum: 1_000 })
  validates(:requirement, inclusion: { in: REQUIREMENTS })
  validates(:position, numericality: { only_integer: true }, uniqueness: true) # rubocop:disable Rails/UniqueValidationWithoutIndex -- it's a deferred unique constraint
  validate(:validate_kind)
  validate(:validate_enabled)

  before_validation(:set_builtin_key)
  before_validation(:assign_position, on: :create)
  before_destroy(:validate_deletable, prepend: true)
  after_commit(-> { UploaderSection.clear_cache })

  modactions(:uploader_section)
    .add(:create, :creator, on: :create) { { label: label } }
    .add(:update, :updater, on: :update) { { label: label, old_label: label_before_last_save } }
    .add(:delete, :destroyer, on: :destroy) { { label: label } }

  def builtin?
    BUILTIN_KINDS.include?(kind)
  end

  def tags?
    kind == "tags"
  end

  def required?
    REQUIRED_KINDS.include?(kind)
  end

  def deletable?
    !builtin?
  end

  def as_layout_json
    {
      kind:                 kind,
      key:                  key,
      label:                label,
      hint:                 hint,
      placeholder:          placeholder,
      requirement:          requirement,
      show_in_compact_mode: show_in_compact_mode,
      rows:                 buttons.group_by(&:row).sort.map { |_row, buttons| buttons.map(&:as_layout_json) },
    }
  end

  module LayoutMethods
    # The enabled sections in order with their buttons, for the uploader
    def layout
      RequestStore.store[:uploader_layout] ||= Cache.fetch("uploader_layout", expires_in: 1.hour) do
        where(is_enabled: true).includes(:buttons).order(:position).map(&:as_layout_json)
      end
    end

    def clear_cache
      Cache.delete("uploader_layout")
      RequestStore.store.delete(:uploader_layout)
    end

    # Creates any of the sections from DEFAULTS_FILE that don't exist yet, at the end
    def create_defaults!(creator_id: User.system.id, creator_ip_addr: "127.0.0.1")
      now = Time.current
      user = { creator_id: creator_id, creator_ip_addr: creator_ip_addr, updater_id: creator_id, updater_ip_addr: creator_ip_addr, created_at: now, updated_at: now }
      position = maximum(:position) || -1
      YAML.load_file(DEFAULTS_FILE).each do |row|
        row = row.symbolize_keys
        buttons = row.delete(:buttons) || []
        row[:key] ||= row[:kind]
        next if exists?(key: row[:key])

        section_id = insert!({ **user, **row, position: position += 1 }, returning: %w[id]).first["id"]
        # insert_all needs every row to have the same keys
        rows = buttons.each_with_index.map do |button, index|
          button = button.symbolize_keys
          { **user, section_id: section_id, tag: UploaderButton.default_tag(button[:name]), row: 1, position: index, shown_when: [], shown_when_mode: "any", **button }
        end
        rows.reject! { |button| UploaderButton.exists?(tag: button[:tag]) }
        UploaderButton.insert_all!(rows) if rows.any?
      end
      clear_cache
    end

    def log_reorder(changes, user)
      ModAction.log!(user, :uploader_sections_reorder, nil, total: changes)
    end

    def available_includes
      %i[creator updater buttons]
    end
  end

  extend(LayoutMethods)

  private

  # built in sections are found by their key
  def set_builtin_key
    self.key = kind if builtin?
  end

  # new sections go at the end, so nothing else has to move
  def assign_position
    self.position ||= (UploaderSection.maximum(:position) || -1) + 1
  end

  def validate_kind
    errors.add(:kind, "can't be changed") if persisted? && kind_changed?
    errors.add(:requirement, "can only be set on tags sections") if !tags? && requirement != "none"
    # "other" is the other tags box
    errors.add(:key, "is reserved") if tags? && [*BUILTIN_KINDS, "other"].include?(key)
  end

  def validate_enabled
    errors.add(:base, "The #{label} section can't be turned off") if required? && !is_enabled?
  end

  def validate_deletable
    unless deletable?
      errors.add(:base, "Built in sections can't be deleted")
      throw(:abort)
    end
    # buttons elsewhere that are only shown by this section's buttons
    names = UploaderButton.where.not(section_id: id).where("shown_when && ARRAY[?]::varchar[]", buttons.pluck(:tag).presence || [""]).pluck(:name)
    return if names.empty?
    errors.add(:base, "#{names.to_sentence} #{names.size == 1 ? 'is' : 'are'} only shown by this section's buttons, change #{names.size == 1 ? 'it' : 'them'} first")
    throw(:abort)
  end
end
