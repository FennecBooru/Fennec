# frozen_string_literal: true

require("test_helper")

# searching with sql has to give the same results as opensearch
class SQLSearchTest < ActiveSupport::TestCase
  def search_results(query, user, page: nil, limit: 3)
    posts = Post.tag_match(query, user)
    {
      ids:     posts.paginate_posts(page, limit: limit, user: user).map(&:id),
      count:   Post.tag_match(query, user).count_only,
      all:     Post.tag_match(query, user).limit(100).map(&:id),
      unpaged: Post.tag_match(query, user).pluck(:id),
    }
  end

  def assert_same_results(query, user = @user, **)
    expected = search_results(query, user, **)
    actual = with_sql_search { search_results(query, user, **) }

    assert_equal(expected, actual, "Query: #{query} #{kwargs_text(**)}")
  end

  def kwargs_text(**options)
    options.map { |k, v| "#{k}: #{v}" }.join(", ")
  end

  def asset(width, height, file_size, **)
    create(:random_upload_media_asset, image_width: width, image_height: height, file_size: file_size, **)
  end

  context("Searching with sql") do
    setup do
      reset_post_index
      @user = create(:user, created_at: 2.weeks.ago)
      @janitor = create(:janitor_user, created_at: 2.weeks.ago)
      create(:tag, name: "fluffy_(oc)", category_id: TagCategory.character)
      create(:tag, name: "rex_(oc)", category_id: TagCategory.character)
      create(:tag, name: "some_artist", category_id: TagCategory.artist)

      @posts = [
        create(:post, tag_string: "fox solo {fluffy_(oc) blue_eyes} some_artist", rating: "s", score: 5, fav_count: 1, description: "The quick brown fox jumps", media_asset: asset(1920, 1080, 2_000_000), created_at: 5.days.ago),
        create(:post, tag_string: "wolf duo {fluffy_(oc) red_eyes} {rex_(oc) blue_eyes}", rating: "q", score: 3, description: "quick brownies", media_asset: asset(800, 1200, 500_000), created_at: 4.days.ago),
        create(:post, tag_string: "fox duo", rating: "e", score: -2, source: "https://Example.net/a\nhttps://other.org/b", media_asset: asset(1000, 1000, 1_000_000), created_at: 3.days.ago),
        create(:post, tag_string: "cat", rating: "s", score: 10, media_asset: asset(3000, 1000, 3_000_000), created_at: 2.days.ago),
        create(:post, tag_string: "cat fox", rating: "q", score: 0, is_pending: true, media_asset: asset(640, 500, 100_000), created_at: 1.day.ago),
        create(:post, tag_string: "dog", rating: "s", score: 1, is_deleted: true, media_asset: asset(500, 400, 50_000), created_at: 6.days.ago),
        create(:post, tag_string: "dog wolf", rating: "e", score: 7, media_asset: asset(1200, 900, 750_000, duration: 12.5, file_ext: "webm"), created_at: 7.days.ago),
      ]
      @posts[1].update!(parent_id: @posts[0].id)
      create(:pool, name: "foxes").tap { |pool| pool.add!(@posts[0], @user) && pool.add!(@posts[2], @user) }
      create(:post_set, creator: @user).tap { |set| set.add!(@posts[3], @user) }
      create(:comment, post: @posts[0], creator: @user)
      create(:note, post: @posts[3], creator: @janitor, body: "look at this tail")
      FavoriteManager.add!(user: @user, post: @posts[2])
      VoteManager::Posts.vote!(user: @janitor, ip_addr: "127.0.0.1", post: @posts[3], score: 1)
      VoteManager::Posts.vote!(user: @janitor, ip_addr: "127.0.0.1", post: @posts[4], score: -1)
      Post.find_each { |post| post.document_store.update_index(refresh: "true") }
    end

    should("match opensearch for searches") do
      [
        "", "fox", "-fox", "fox duo", "~fox ~cat", "fox -duo", "( fox ~ cat ) -dog", "-( fox duo )",
        "{fluffy_(oc) blue_eyes}", "-{fluffy_(oc) red_eyes}", "{rex_(oc) red_eyes}",
        "rating:s", "-rating:s", "rating:q ~rating:e", "score:>2", "score:-2..3", "score:<=0",
        "width:>1000", "height:1000", "mpixels:>1", "ratio:>1.5", "ratio:1", "filesize:>600kb", "duration:>10", "filetype:webm",
        "status:any", "status:pending", "status:deleted", "-status:pending", "status:active", "status:modqueue",
        "pool:any", "pool:none", "inpool:true", "parent:any", "parent:none", "child:any", "ischild:true", "isparent:true",
        "fav:#{@user.name}", "-fav:#{@user.name}", "upvote:#{@janitor.name}", "downvote:#{@janitor.name}", "commenter:any", "noter:any",
        "description:quick", "description:\"quick brown\"", "description:brow", "note:tail", "hassource:true", "hasdescription:false",
        "source:*other.org*", "source:https://example.net/*", "user:#{@user.name}", "-user:#{@user.name}",
        "chartags:>0", "chartags:0", "arttags:1", "gentags:>=2", "tagcount:>2", "age:<4d", "date:>#{4.days.ago.to_date}",
        "artverified:true", "comment_count:>0", "id:#{@posts[2].id}", "id:<#{@posts[3].id}",
      ].each { |query| assert_same_results(query) }
    end

    should("match opensearch for orders") do
      %w[
        id id_desc change change_asc score score_asc favcount favcount_asc created_at created_at_asc updated updated_asc
        mpixels mpixels_asc portrait landscape filesize filesize_asc tagcount tagcount_asc chartags chartags_asc
        gentags gentags_asc comment comment_asc note note_asc duration duration_asc md5 md5_asc comment_count comment_count_asc
      ].each { |order| assert_same_results("status:any order:#{order}") }
    end

    should("match opensearch for pagination") do
      ["", "order:score", "status:any"].each do |query|
        [nil, "2", "3", "b#{@posts[3].id}", "a#{@posts[1].id}"].each do |page|
          assert_same_results(query, page: page, limit: 2)
        end
      end
    end

    should("match opensearch for hidden and safe mode posts") do
      assert_same_results("", User.anonymous)
      @user.update!(enable_safe_mode: true)

      assert_same_results("", @user)
    end

    should("give the same random posts for a seed") do
      expected = Post.tag_match("order:random randseed:5", @user).limit(100).map(&:id)
      actual = with_sql_search { Post.tag_match("order:random randseed:5", @user).limit(100).map(&:id) }

      assert_equal(expected.sort, actual.sort)
      assert_equal(actual, with_sql_search { Post.tag_match("order:random randseed:5", @user).limit(100).map(&:id) })
    end

    should("match opensearch for post versions") do
      PostVersion.find_each { |version| version.document_store.update_index(refresh: "true") }
      [
        {}, { post_id: @posts[0].id.to_s }, { updater_id: @user.id.to_s }, { tags: "fox" }, { tags_added: "duo" },
        { rating: "s" }, { uploads: "only" }, { uploads: "excluded" }, { parent_id_changed: "any" }, { order: "id_asc" },
      ].each do |params|
        expected = PostVersion.search(params, @user).limit(100).map(&:id)
        actual = with_sql_search { PostVersion.search(params, @user).limit(100).map(&:id) }

        assert_equal(expected, actual, "Params: #{params}")
      end
    end

    should("not index anything") do
      with_sql_search do
        Post.any_instance.unstub(:skip_index_update)
        DocumentStore.expects(:client).never
        create(:post).update!(tag_string: "changed")
      end
    end
  end
end
