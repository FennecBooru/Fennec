# frozen_string_literal: true

require("test_helper")

class StaticControllerTest < ActionDispatch::IntegrationTest
  context("The static controller") do
    context("the robots action") do
      should("render") do
        assert_nothing_raised { get(robots_path) }
      end
    end

    context("the site map action") do
      should("render for anonymous users") do
        get(site_map_path)

        assert_response(:success)
        assert_select("#a-site-map section h1", text: "Posts")
      end

      should("render for staff") do
        get_auth(site_map_path, create(:owner_user))

        assert_response(:success)
        assert_select("#a-site-map section h1", text: "Admin")
      end
    end

    context("the browserconfig action") do
      should("use the site icons") do
        get("/browserconfig.xml")

        assert_response(:success)
        tile = Nokogiri::XML(response.body).at("msapplication tile")

        assert_equal(SiteAsset.file_url("ms-icon-150x150.png"), tile.at("square150x150logo")["src"])
        assert_equal("#222222", tile.at("TileColor").text)
      end
    end

    context("the manifest action") do
      should("use the configured app name") do
        AdminConfig.any_instance.stubs(:app_name).returns("Test Site")
        get("/manifest.json")

        assert_response(:success)
        assert_equal("Test Site", response.parsed_body["name"])
        assert_equal(6, response.parsed_body["icons"].length)
      end
    end

    context("the discord action") do
      setup do
        @user = create(:user, created_at: 2.weeks.ago)
      end

      should("render") do
        get_auth(discord_get_path, @user)

        assert_response(:success)
        assert_select("#nav a[href='#{discord_get_path}']")
      end

      context("when discord is disabled") do
        setup do
          stub_admin_config(:enable_discord, false)
        end

        should("not be available") do
          get_auth(discord_get_path, @user)

          assert_response(:not_found)
          get_auth(discord_get_path, create(:moderator_user))

          assert_response(:not_implemented)
        end

        should("hide the links") do
          get_auth(site_map_path, @user)

          assert_select("a[href='#{discord_get_path}']", count: 0)
        end
      end
    end
  end
end
