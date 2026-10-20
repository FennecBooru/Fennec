# frozen_string_literal: true

require("test_helper")

module Posts
  class RecommendationsControllerTest < ActionDispatch::IntegrationTest
    context("The recommendations controller") do
      setup do
        Fennec.config.stubs(:recommender_server).returns("http://recommender:5000")
        @user = create(:user)
        @post = create(:post)
      end

      context("show action") do
        should("render") do
          Recommender.expects(:recommend_for_post).returns([{ score: 1, post: @post }])
          get_auth(post_recommendations_path, @user, params: { search: { post_id: @post.id } })

          assert_response(:success)
        end

        should("not be available when disabled in the config") do
          AdminConfig.any_instance.stubs(:enable_recommendations).returns(false)
          Recommender.expects(:recommend_for_post).never
          get_auth(post_recommendations_path, @user, params: { search: { post_id: @post.id } })

          assert_response(:not_implemented)
        end

        should("not be available without a recommender server") do
          Fennec.config.stubs(:recommender_server).returns(nil)
          get_auth(post_recommendations_path, @user)

          assert_response(:not_implemented)
        end
      end

      context("post page") do
        should("link to recommendations only when enabled") do
          get_auth(post_path(@post), @user)

          assert_select("a[href^='#{post_recommendations_path}']")

          AdminConfig.any_instance.stubs(:enable_recommendations).returns(false)
          get_auth(post_path(@post), @user)

          assert_select("a[href^='#{post_recommendations_path}']", count: 0)
        end
      end
    end
  end
end
