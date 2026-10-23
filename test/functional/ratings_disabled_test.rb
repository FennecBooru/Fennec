# frozen_string_literal: true

require("test_helper")

class RatingsDisabledTest < ActionDispatch::IntegrationTest
  context("With ratings disabled") do
    setup do
      stub_admin_config(:enable_ratings, false)
      @user = create(:janitor_user)
      @post = create(:post, rating: "s")
    end

    should("save uploads as questionable") do
      upload = CurrentUser.scoped(@user) { create(:jpg_upload, uploader: @user, tag_string: "aaa rating:e", rating: "s") }

      assert_equal("q", upload.post.rating)
    end

    should("ignore rating changes") do
      put_auth(post_path(@post), @user, params: { post: { rating: "e", old_rating: "s" } })
      CurrentUser.scoped(@user) { @post.update(tag_string: "#{@post.tag_string} rating:e locked:rating") }

      @post.reload

      assert_equal("s", @post.rating)
      assert_not(@post.is_rating_locked?)
    end

    should("not hide posts from safe mode because of their rating") do
      user = create(:user, enable_safe_mode: true)
      post = create(:post, rating: "e")

      assert_not(post.safeblocked?(user))
      assert_equal("-status:deleted", PostSets::Post.new("", current_user: user).tag_array.join(" "))
    end

    should("hide the rating on the post page") do
      get_auth(post_path(@post), @user)

      assert_response(:success)
      assert_select("#post-rating-text", count: 0)
      assert_select("input[name='post[rating]']", count: 0)
    end

    should("leave the rating sections out of the uploader") do
      kinds = CurrentUser.scoped(@user) { UploadSettings.new(@user).layout.pluck(:kind) }

      assert_not_includes(kinds, "rating")
      assert_not_includes(kinds, "lock_rating")
    end
  end
end
