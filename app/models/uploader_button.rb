# frozen_string_literal: true

# A button in a tags section of the uploader, which adds its tag while selected. A button with shown_when is only shown
# while any (or all) of those tags are selected, and is unselected when it's hidden.
class UploaderButton < ApplicationRecord
  MODES = %w[any all].freeze

  belongs_to(:section, class_name: "UploaderSection", inverse_of: :buttons)
  belongs_to_user(:creator, ip: true, clones: :updater)
  belongs_to_user(:updater, ip: true)
  resolvable(:destroyer)

  array_attribute(:shown_when, parse: /[^\s,]+/, join_character: " ")

  normalizes(:name, with: ->(name) { name.to_s.strip })
  normalizes(:tag, with: ->(tag) { Tag.normalize_name(tag.to_s) })
  normalizes(:shown_when, with: ->(tags) { tags.map { |tag| Tag.normalize_name(tag) }.compact_blank.uniq })

  validates(:name, presence: true, length: { maximum: 100 })
  # the uploader keeps track of what's selected by tag
  validates(:tag, presence: true, uniqueness: true, length: { maximum: 100 })
  validates(:row, numericality: { only_integer: true, greater_than: 0 })
  validates(:position, numericality: { only_integer: true })
  validates(:shown_when_mode, inclusion: { in: MODES })
  validate(:validate_section)
  validate(:validate_shown_when)
  validate(:validate_tag_change, on: :update, if: :tag_changed?)

  before_validation(:set_default_tag)
  before_validation(:assign_position, on: :create)
  before_destroy(:validate_deletable, prepend: true)
  after_commit(-> { UploaderSection.clear_cache })

  modactions(:uploader_button)
    .add(:create, :creator, on: :create) { { name: name, section_label: section.label } }
    .add(:update, :updater, on: :update) { { name: name, section_label: section.label } }
    .add(:delete, :destroyer, on: :destroy) { { name: name, section_label: section.label } }

  def self.default_tag(name)
    name.to_s.strip.downcase.tr(" ", "_")
  end

  def self.log_reorder(section, changes, user)
    ModAction.log!(user, :uploader_buttons_reorder, nil, total: changes, section_label: section.label)
  end

  def self.available_includes
    %i[creator updater section]
  end

  # the buttons that are only shown while this one's tag is selected
  def dependents(tag = self.tag)
    UploaderButton.where.not(id: id).where("? = ANY(shown_when)", tag)
  end

  def as_layout_json
    { name: name, tag: tag, shown_when: shown_when, shown_when_mode: shown_when_mode }
  end

  private

  def set_default_tag
    self.tag = UploaderButton.default_tag(name) if tag.blank?
  end

  # new buttons go at the end of their row
  def assign_position
    return if section.nil? || position_changed?
    self.position = (section.buttons.maximum(:position) || -1) + 1
  end

  def validate_section
    errors.add(:section, "must be a tags section") if section.present? && !section.tags?
  end

  def validate_shown_when
    return if shown_when.empty?
    errors.add(:shown_when, "can't include its own tag") if shown_when.include?(tag)
    missing = shown_when - UploaderButton.where(tag: shown_when).pluck(:tag)
    errors.add(:shown_when, "includes tags no button has: #{missing.join(', ')}") if missing.any?
  end

  def validate_tag_change
    names = dependents(tag_was).pluck(:name)
    errors.add(:tag, "can't be changed while #{names.to_sentence} #{names.size == 1 ? 'is' : 'are'} shown by it") if names.any?
  end

  def validate_deletable
    names = dependents.pluck(:name)
    return if names.empty?
    errors.add(:base, "#{names.to_sentence} #{names.size == 1 ? 'is' : 'are'} only shown when this button is selected, change #{names.size == 1 ? 'it' : 'them'} first")
    throw(:abort)
  end
end
