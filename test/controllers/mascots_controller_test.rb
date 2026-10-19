# frozen_string_literal: true

require("test_helper")

class MascotsControllerTest < ActionDispatch::IntegrationTest
  context("The mascots controller") do
    setup do
      @admin = create(:admin_user)
      @mascot = create(:mascot, available_on: [AdminConfig.instance.app_name])
    end

    should("show the active mascots on the home page") do
      get(root_path)

      assert_response(:success)
      assert_select("meta[name='active-mascots'][content*='\"id\":#{@mascot.id}']")
      assert_select("#change-mascot")
    end

    context("when mascots are disabled") do
      setup do
        stub_admin_config(:enable_mascots, false)
      end

      should("not be available") do
        assert_feature_unavailable([mascots_path, new_mascot_path, edit_mascot_path(@mascot), mascot_media_assets_path], as: @admin)
      end

      should("not show mascots on the home page") do
        get(root_path)

        assert_response(:success)
        assert_select("meta[name='active-mascots'][content='{}']")
        assert_select("#change-mascot", count: 0)

        get_auth(site_map_path, @admin)

        assert_select("a[href='#{mascots_path}']", count: 0)
      end
    end
  end
end
