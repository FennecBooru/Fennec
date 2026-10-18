# frozen_string_literal: true

class TransferTagCategoryTagsJob < ApplicationJob
  queue_as(:default)
  good_job_control_concurrency_with(total_limit: 1, key: -> { "TransferTagCategoryTagsJob-#{arguments[1].id}" })

  def perform(user, old_category, new_category)
    moved = 0
    old_min_level = old_category.min_level
    # nothing new can be put in the category while its tags are being moved
    old_category.update_columns(min_level: User::Levels::LOCKED)
    TagCategory.clear_cache

    Tag.where(category_id: old_category.id).find_each do |tag|
      # each tag queues UpdateTagCategoryJob to update its posts
      if tag.update(category_id: new_category.id, updater: user.resolvable, reason: "Moved from the #{old_category.name} category")
        moved += 1
      else
        Rails.logger.warn("TransferTagCategoryTagsJob: couldn't move #{tag.name}: #{tag.errors.full_messages.join('; ')}")
      end
    end
  ensure
    old_category.update_columns(min_level: old_min_level)
    TagCategory.clear_cache
    ModAction.log!(user.resolvable, :tag_category_tags_transfer, old_category, total: moved, old_category_name: old_category.name, category_name: new_category.name)
  end
end
