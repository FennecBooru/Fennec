# frozen_string_literal: true

module BulkUpdateRequestCommands
  class ChangeCategory < Base
    set_command(:change_category)
    set_arguments(:tag_name, :category, :comment)
    set_regex(/\A(?:change category|category) (\S+) -> (\S+)(?: # ?(.*))?\z/i, %i[tag downcase pass])
    set_untokenize { |tag, category, comment| "category #{tag} -> #{category}#{" # #{comment}" if comment}" }
    set_to_dtext { |tag, category, comment| "category [[#{tag.name}]] (#{tag.post_count}) -> #{category}#{" # #{comment}" if comment}" }

    validate(:tag_exists)
    validate(:category_exists)

    def tag_exists
      comments.add(:base, "missing") if tag.nil?
    end

    def category_exists
      errors.add(:base, "invalid category") unless TagCategory.mapping.key?(category.downcase)
    end

    def estimate_update_count
      tag.try(:post_count) || 0
    end

    def tags
      [tag_name]
    end

    def approved?
      Tag.exists?(name: tag_name, category: TagCategory.value_for(category)) || (tag.blank? && TagCategory.value_for(category) == TagCategory.general)
    end

    def category_changes
      return [] if approved?
      [[tag || Tag.new(name: tag_name), TagCategory.value_for(category)]]
    end

    def process(_processor, approver)
      ensure_valid!

      tag = Tag.find_or_create_by_name(tag_name, user: approver)
      tag.update_with!(approver, category: TagCategory.value_for(category))
    end
  end
end
