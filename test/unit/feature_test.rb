# frozen_string_literal: true

require("test_helper")

class FeatureTest < ActiveSupport::TestCase
  context("Feature") do
    should("read the admin config column") do
      assert(Feature.enabled?(:forums))

      stub_admin_config(:enable_forums, false)

      assert_not(Feature.enabled?(:forums))
    end

    should("raise for unknown features") do
      assert_raises(ArgumentError) { Feature.enabled?(:nonexistent) }
    end

    should("have a column for every feature") do
      Feature.definitions.each do |feature|
        assert_includes(AdminConfig.column_names, feature.column.to_s, feature.name)
      end
    end

    should("only stay available to staff for features with staff access") do
      stub_admin_config(:enable_wiki, false)
      stub_admin_config(:enable_forums, false)

      assert(Feature.available?(:wiki, create(:moderator_user)))
      assert_not(Feature.available?(:wiki, create(:user)))
      assert_not(Feature.available?(:forums, create(:moderator_user)))
    end
  end
end
