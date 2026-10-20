# frozen_string_literal: true

require("test_helper")

class EmailDisabledTest < ActionDispatch::IntegrationTest
  context("With email disabled") do
    setup do
      Fennec.config.stubs(:enable_email?).returns(false)
      AdminConfig.any_instance.stubs(:enable_email_verification).returns(true)
      AdminConfig.any_instance.stubs(:enable_email_verification?).returns(true)
      ActionMailer::Base.perform_deliveries = true
      ActionMailer::Base.deliveries = []
      @user = create(:user, email_verified: false)
    end

    should("allow signing up without an email") do
      assert_difference(-> { User.count }, 1) do
        post(users_path, params: { user: { name: "noemail", password: "xxxxxx", password_confirmation: "xxxxxx" } })
      end

      user = User.find_by!(name: "noemail")

      assert_predicate(user, :is_verified?)
      assert_empty(ActionMailer::Base.deliveries)
    end

    should("treat every user as verified") do
      assert_predicate(@user, :is_verified?)
    end

    should("not send emails") do
      Users::LoginReminderMailer.notice(@user).deliver_now
      create(:dmail, to: @user)

      assert_empty(ActionMailer::Base.deliveries)
    end

    should("not allow subscribing to forum topics") do
      assert_not(ForumTopicPolicy.new(@user, create(:forum_topic)).subscribe?)
    end

    should("disable the email pages") do
      get(new_users_password_reset_path)

      assert_response(:not_implemented)

      get(new_users_login_reminder_path)

      assert_response(:not_implemented)

      get_auth(new_users_email_change_path, @user)

      assert_response(:not_implemented)

      get_auth(users_email_notification_path, @user)

      assert_response(:not_implemented)

      get_auth(email_blacklists_path, create(:admin_user))

      assert_response(:not_implemented)
    end

    should("not need the email key") do
      Fennec.config.stubs(:env).returns(nil)

      assert_nil(Fennec.config.email_key)
    end

    should("hide the email links") do
      get(new_session_path)

      assert_select("a[href='#{new_users_password_reset_path}']", count: 0)
      assert_select("input#user_email", count: 0)
    end
  end
end
