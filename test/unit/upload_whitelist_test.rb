# frozen_string_literal: true

require("test_helper")

class UploadWhitelistTest < ActiveSupport::TestCase
  context("A upload whitelist") do
    setup do
      @user = create(:trusted_user)

      @whitelist = create(:upload_whitelist, pattern: "#{Fennec.config.hostname}/*", note: "local")
      if Fennec.config.hostname != Fennec.config.cdn_hostname
        @whitelist = create(:upload_whitelist, pattern: "#{Fennec.config.cdn_hostname}/*", note: "cdn")
      end
    end

    should("match") do
      assert_equal([true, nil], UploadWhitelist.is_whitelisted?(Addressable::URI.parse("#{Fennec.config.hostname}/123.png"), @user))
      assert_equal([true, nil], UploadWhitelist.is_whitelisted?(Addressable::URI.parse("#{Fennec.config.cdn_hostname}/123.png"), @user))
      assert_equal([false, "123.com not in whitelist"], UploadWhitelist.is_whitelisted?(Addressable::URI.parse("https://123.com/what.png"), @user))
    end

    should("bypass for admins") do
      @user.update_columns(level: User::Levels::ADMIN)

      assert_equal([true, "bypassed"], UploadWhitelist.is_whitelisted?(Addressable::URI.parse("https://123.com/what.png"), @user))
    end

    context("when the whitelist is disabled") do
      setup do
        stub_admin_config(:enable_upload_whitelist, false)
      end

      should("allow any public url") do
        Addrinfo.stubs(:getaddrinfo).returns([Addrinfo.tcp("93.184.216.34", 0)])

        assert_equal([true, nil], UploadWhitelist.is_whitelisted?(Addressable::URI.parse("https://123.com/what.png"), @user))
      end

      should("not allow internal addresses") do
        Addrinfo.stubs(:getaddrinfo).returns([Addrinfo.tcp("169.254.169.254", 0)])

        assert_equal([false, "Downloads from 169.254.169.254 are not allowed"], UploadWhitelist.is_whitelisted?(Addressable::URI.parse("http://metadata.example/latest"), @user))
      end

      should("not allow embedded credentials") do
        assert_equal([false, "URLs with embedded credentials are not allowed"], UploadWhitelist.is_whitelisted?(Addressable::URI.parse("https://a:b@123.com/what.png"), @user))
      end
    end
  end
end
