# frozen_string_literal: true

require("test_helper")

class UploadWhitelistsControllerTest < ActionDispatch::IntegrationTest
  context("The upload whitelists controller") do
    setup do
      @admin = create(:admin_user)
      @whitelist = create(:upload_whitelist, pattern: "https://example.com/*")
    end

    context("when the whitelist is disabled") do
      setup do
        stub_admin_config(:enable_upload_whitelist, false)
      end

      should("not show the whitelist") do
        [upload_whitelists_path, new_upload_whitelist_path, edit_upload_whitelist_path(@whitelist)].each do |path|
          get_auth(path, @admin)

          assert_response(:not_implemented, path)
        end

        get_auth(site_map_path, @admin)

        assert_select("a[href='#{upload_whitelists_path}']", count: 0)
      end

      should("still check urls for the uploader") do
        Addrinfo.stubs(:getaddrinfo).returns([Addrinfo.tcp("93.184.216.34", 0)])
        get_auth(is_allowed_upload_whitelists_path, create(:user), params: { url: "https://anywhere.example/a.png", format: :json })

        assert_response(:success)
        assert(response.parsed_body["is_allowed"])
      end
    end
  end
end
