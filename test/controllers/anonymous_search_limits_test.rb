# frozen_string_literal: true

require("test_helper")

# Middleware::AnonymousSearchLimits through the whole stack
class AnonymousSearchLimitsIntegrationTest < ActionDispatch::IntegrationTest
  context("A post search over the anonymous limits") do
    setup do
      @user = create(:user)
      stub_admin_config(:anonymous_hard_tag_limit, 2)
    end

    should("be rejected without rendering the site for anonymous users") do
      get(posts_path, params: { tags: "a b c" })

      assert_response(:unprocessable_content)
      assert_select("#page", count: 0)
      assert_includes(response.body, "Your query exceeds the limit")
    end

    should("allow anonymous searches at the limits, despite the terms the app adds") do
      stub_admin_config(:anonymous_negated_tag_limit, 1)
      get(posts_path, params: { tags: "a -b" })

      assert_response(:success)
    end

    should("work for logged in users") do
      get_auth(posts_path, @user, params: { tags: "a b c" })

      assert_response(:success)
    end
  end
end
