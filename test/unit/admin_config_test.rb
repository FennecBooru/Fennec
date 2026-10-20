# frozen_string_literal: true

require("test_helper")

class AdminConfigTest < ActiveSupport::TestCase
  # columns added by a test are only gone once its transaction rolls back, which happens after teardown
  def after_teardown
    super
    AdminConfig.connection.clear_cache!
    AdminConfig.reset_column_information
    AdminConfig.delete_cache
  end

  context("AdminConfig env overrides") do
    teardown do
      ENV.delete("FENNEC_ADMIN_CONFIG_RECORDS_PER_PAGE")
      ENV.delete("FENNEC_ADMIN_CONFIG_ENABLE_SIGNUPS")
      ENV.delete("FENNEC_ADMIN_CONFIG_IMAGE_WIDTH")
      ENV.delete("FENNEC_ADMIN_CONFIG_COMMENT_LIMIT_BYPASS")
    end

    should("pin an integer column to the env value") do
      ENV["FENNEC_ADMIN_CONFIG_RECORDS_PER_PAGE"] = "42"

      assert_equal(42, AdminConfig.uncached.records_per_page)
      assert_equal(42, AdminConfig.get(:records_per_page))
    end

    should("pin a boolean column to the env value") do
      ENV["FENNEC_ADMIN_CONFIG_ENABLE_SIGNUPS"] = "false"

      assert_not(AdminConfig.uncached.enable_signups)
      assert_not(AdminConfig.uncached.enable_signups?)
    end

    should("pin a jsonb column to the parsed env value") do
      ENV["FENNEC_ADMIN_CONFIG_IMAGE_WIDTH"] = '{"min":10,"max":20}'

      assert_equal({ "min" => 10, "max" => 20 }, AdminConfig.uncached.image_width)
    end

    should("apply the override to bypass columns too") do
      ENV["FENNEC_ADMIN_CONFIG_COMMENT_LIMIT_BYPASS"] = "0"
      user = create(:anonymous_user)

      assert(AdminConfig.bypass?(:comment_limit, user))
    end

    should("exclude overridden columns from settable_columns") do
      ENV["FENNEC_ADMIN_CONFIG_RECORDS_PER_PAGE"] = "42"
      user = create(:owner_user)

      assert_not_includes(AdminConfig.settable_columns(user).map(&:name), "records_per_page")
      assert_not(AdminConfig.usable?(user, :records_per_page))
    end
  end

  context("AdminConfig class readers") do
    should("read columns") do
      assert_equal(AdminConfig.instance.records_per_page, AdminConfig.records_per_page)
      assert_equal(AdminConfig.instance.enable_signups, AdminConfig.enable_signups?)
      assert_respond_to(AdminConfig, :records_per_page)
      assert_raises(NoMethodError) { AdminConfig.not_a_column }
    end

    should("read columns added after the schema was loaded") do
      AdminConfig.column_names
      AdminConfig.connection.add_column(:admin_config, :test_column, :integer, null: false, default: 5)
      AdminConfig.reset_column_information
      AdminConfig.delete_cache

      assert_equal(5, AdminConfig.test_column)
      assert_equal(5, AdminConfig.instance.test_column)
    end

    should("not use a row cached before a column was added") do
      AdminConfig.instance
      AdminConfig.connection.add_column(:admin_config, :test_column, :integer, null: false, default: 5)
      AdminConfig.reset_column_information

      assert_equal(5, AdminConfig.instance.test_column)
    end
  end
end
