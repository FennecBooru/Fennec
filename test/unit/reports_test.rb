# frozen_string_literal: true

require("test_helper")

class ReportsTest < ActiveSupport::TestCase
  context("Reports") do
    setup do
      Reports.stubs(:configured?).returns(true)
    end

    should("be enabled when configured") do
      assert_predicate(Reports, :enabled?)
      assert_predicate(Reports, :view_tracking_enabled?)
      assert_predicate(Reports, :search_tracking_enabled?)
      assert_predicate(Reports, :api_key_usage_tracking_enabled?)
    end

    should("disable everything when reports are disabled") do
      stub_admin_config(:enable_reports, false)

      assert_not(Reports.enabled?)
      assert_not(Reports.view_tracking_enabled?)
      assert_not(Reports.search_tracking_enabled?)
      assert_not(Reports.api_key_usage_tracking_enabled?)
      assert_equal(0, Reports.get_post_views(1))
      assert_equal([], Reports.get_post_searches_rank(Time.now))
    end

    should("disable each kind of tracking separately") do
      stub_admin_config(:enable_view_tracking, false)
      stub_admin_config(:enable_api_key_usage_tracking, false)

      assert_not(Reports.view_tracking_enabled?)
      assert_predicate(Reports, :search_tracking_enabled?)
      assert_not(Reports.api_key_usage_tracking_enabled?)
      Reports.expects(:post).never

      assert_not(Reports.log_api_key_usage(1, "posts", "index", "GET", "/posts.json", "127.0.0.1"))
    end

    should("not be enabled without a server") do
      Reports.unstub(:configured?)

      assert_not(Reports.enabled?)
    end
  end
end
