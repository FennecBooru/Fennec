# frozen_string_literal: true

module BulkUpdateRequestCommands
  class Undeprecate < Base
    set_command(:undeprecate)
    set_arguments(:tag_name, :comment)
    set_regex(/\Aundeprecate (\S+)(?: # ?(.*))?\z/i, %i[tag pass])
    set_untokenize { |tag_name, comment| "undeprecate #{tag_name}#{" # #{comment}" if comment}" }
    set_to_dtext { |tag, comment| "undeprecate [[#{tag.name}]] (#{tag.post_count})#{" # #{comment}" if comment}" }

    validate(:tag_exists)
    validate(:deprecated)

    def tag_exists
      comments.add(:base, "missing") if tag.blank?
    end

    def deprecated
      comments.add(:base, "not deprecated") if tag.present? && !tag.is_deprecated?
    end

    def tags
      [tag_name]
    end

    def approved?
      Tag.exists?(name: tag_name, is_deprecated: false)
    end

    def category_changes
      return [] unless tag && TagCategory.general && tag.category == TagCategory.invalid
      [[tag, TagCategory.general]]
    end

    def process(_processor, approver)
      ensure_valid!
      tag = Tag.find_or_create_by_name(tag_name, user: approver)
      tag.category = TagCategory.general if TagCategory.general && tag.category == TagCategory.invalid
      tag.is_deprecated = false
      tag.save!
    end
  end
end
