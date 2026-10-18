# frozen_string_literal: true

require("test_helper")

class UsersHelperTest < ActionView::TestCase
  context("user_level") do
    should("style a level from its id") do
      assert_equal(%(<span class="with-style user-former-staff">Former Staff</span>), user_level(User::Levels::FORMER_STAFF))
    end

    should("style a level from its name") do
      expected = %(<span class="with-style user-admin">Admin</span>)

      assert_equal(expected, user_level("Admin"))
      assert_equal(expected, user_level("admin"))
      assert_equal(%(<span class="with-style user-former-staff">Former Staff</span>), user_level("former_staff"))
      assert_equal(%(<span class="with-style user-former-staff">Former Staff</span>), user_level("Former Staff"))
    end

    should("output nothing for an unknown name") do
      assert_equal("", user_level("nope"))
    end
  end
end
