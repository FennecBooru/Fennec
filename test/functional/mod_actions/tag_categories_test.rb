# frozen_string_literal: true

require("test_helper")
require_relative("helper")

module ModActions
  class TagCategoriesTest < ActiveSupport::TestCase
    include(Helper)
    include(Rails.application.routes.url_helpers)

    context("mod actions for tag categories") do
      setup do
        @category = create(:tag_category, creator: @admin)
        set_count!
      end

      should("format tag_category_create correctly") do
        @category = create(:tag_category, creator: @admin)

        assert_matches(
          actions: %w[tag_category_create],
          text:    "Created tag category \"#{@category.name}\"",
          subject: @category,
          name:    @category.name,
        )
      end

      should("format tag_category_delete correctly") do
        @category.remove(@admin)

        assert_matches(
          actions: %w[tag_category_delete],
          text:    "Deleted tag category \"#{@category.name}\"",
          subject: @category,
          name:    @category.name,
        )
      end

      should("format tag_category_delete correctly for soft deletions") do
        create(:tag, category_id: @category.id)
        # the tag version keeps the category id, so it had tags
        Tag.where(category_id: @category.id).update_all(category_id: TagCategory.default_id)
        set_count!
        @category.remove(@admin)

        assert_predicate(@category.reload, :is_deleted?)
        assert_matches(
          actions: %w[tag_category_delete],
          text:    "Deleted tag category \"#{@category.name}\"",
          subject: @category,
          name:    @category.name,
        )
      end

      should("format tag_categories_reorder correctly") do
        TagCategory.log_reorder(2, @admin)

        assert_matches(
          actions: %w[tag_categories_reorder],
          text:    "Changed the order of 2 tag categories",
          subject: nil,
          total:   2,
        )
      end

      should("format tag_category_tags_transfer correctly") do
        create_list(:tag, 2, category_id: @category.id)
        @new_category = create(:tag_category, creator: @admin)
        set_count!
        with_inline_jobs { @category.transfer_tags(@new_category, @admin) }

        assert_matches(
          actions:           %w[tag_category_tags_transfer],
          text:              "Moved 2 tags from tag category \"#{@category.name}\" to \"#{@new_category.name}\"",
          subject:           @category,
          total:             2,
          old_category_name: @category.name,
          category_name:     @new_category.name,
        )
      end

      context("tag_category_update") do
        should("format no changes correctly") do
          @category.update_with!(@admin)

          assert_matches(
            actions:  %w[tag_category_update],
            text:     "Updated tag category \"#{@category.name}\"",
            subject:  @category,
            name:     @category.name,
            old_name: @category.name,
          )
        end

        should("format name changes correctly") do
          old_name = @category.name
          @category.update_with!(@admin, name: "xxx")

          assert_matches(
            actions:  %w[tag_category_update],
            text:     <<~TEXT.strip,
              Updated tag category "xxx"
              Changed name from "#{old_name}" to "xxx"
            TEXT
            subject:  @category,
            name:     "xxx",
            old_name: old_name,
          )
        end
      end
    end
  end
end
