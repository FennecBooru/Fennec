# frozen_string_literal: true

require("test_helper")

class TransferTagCategoryTagsJobTest < ActiveSupport::TestCase
  context("TransferTagCategoryTagsJob") do
    setup do
      @admin = create(:admin_user)
      @old = create(:tag_category, name: "oldcat", min_level: User::Levels::MEMBER)
      @new = create(:tag_category, name: "newcat")
      @tags = create_list(:tag, 2, category: @old.id)
      @post = create(:post, tag_string: @tags.map(&:name).join(" "))
    end

    should("move every tag and log it") do
      assert_difference(-> { TagVersion.count } => 2, -> { ModAction.where(action: "tag_category_tags_transfer").count } => 1) do
        TransferTagCategoryTagsJob.perform_now(@admin, @old, @new)
      end

      assert_equal([@new.id] * 2, @tags.map { |tag| tag.reload.category })
      assert_equal(User::Levels::MEMBER, @old.reload.min_level)
      assert_equal(2, ModAction.last.total)
    end

    should("leave tags the new category won't take") do
      @new.update!(suffixes: %w[needed], updater: @admin)
      TransferTagCategoryTagsJob.perform_now(@admin, @old, @new)

      assert_equal([@old.id] * 2, @tags.map { |tag| tag.reload.category })
      assert_equal(0, ModAction.last.total)
    end

    should("let the category be deleted once its posts are updated") do
      assert_not(@old.deletable?)

      TransferTagCategoryTagsJob.perform_now(@admin, @old, @new)
      # after the tags are saved, like they'd run normally
      perform_enqueued_jobs(only: UpdateTagCategoryJob)

      assert_equal({ @new.id.to_s => 2 }, @post.reload.tag_category_data)
      assert_predicate(@old.reload, :deletable?)
      assert(@old.remove(@admin))
      # its id is still in tag versions, so it's only marked deleted
      assert_predicate(@old.reload, :is_deleted?)
    end
  end
end
