# frozen_string_literal: true

require("test_helper")

class CLITest < ActiveSupport::TestCase
  def run_cli(*args)
    status = 0
    out, err = capture_io do
      CLI::Runner.start(args)
    rescue SystemExit => e
      status = e.status
    end
    [out, err, status]
  end

  context("The command line") do
    setup do
      @user = create(:user, name: "someone")
    end

    should("list the groups") do
      out, = run_cli("help")

      assert_match(/users:COMMAND/, out)
      assert_match(/config:COMMAND/, out)
    end

    should("accept group command as well as group:command") do
      assert_equal(run_cli("users:show", "someone").first, run_cli("users", "show", "someone").first)
    end

    should("fail for unknown users") do
      _, err, status = run_cli("users:show", "nobody")

      assert_equal(1, status)
      assert_match(/No user found for nobody/, err)
    end

    context("users") do
      should("create a user") do
        out, = run_cli("users:create", "newuser", "--level", "admin")
        user = User.find_by!(name: "newuser")

        assert_equal(User::Levels::ADMIN, user.level)
        assert(User.authenticate("newuser", out[/Password: (\S+)/, 1]))
      end

      should("create a user with a given password") do
        out, = run_cli("users:create", "newuser", "--password", "hunter22", "--level", "40")

        assert_no_match(/Password:/, out)
        assert(User.authenticate("newuser", "hunter22"))
      end

      context("with email verification enabled") do
        setup do
          AdminConfig.any_instance.stubs(:enable_email_verification).returns(true)
          AdminConfig.any_instance.stubs(:enable_email_verification?).returns(true)
          ActionMailer::Base.perform_deliveries = true
          ActionMailer::Base.deliveries = []
        end

        should("require an email") do
          _, err, status = run_cli("users:create", "newuser")

          assert_equal(1, status)
          assert_match(/Email can't be blank/, err)
          assert_not(User.exists?(name: "newuser"))
        end

        should("send a confirmation email") do
          run_cli("users:create", "newuser", "--email", "new@example.com")

          assert_not(User.find_by!(name: "newuser").is_verified?)
          assert_equal(["new@example.com"], ActionMailer::Base.deliveries.flat_map(&:to))
        end

        should("mark the user verified when asked") do
          run_cli("users:create", "newuser", "--email", "new@example.com", "--verified")

          assert_predicate(User.find_by!(name: "newuser"), :is_verified?)
          assert_empty(ActionMailer::Base.deliveries)
        end
      end

      should("report validation errors") do
        _, err, status = run_cli("users:create", "someone")

        assert_equal(1, status)
        assert_match(/already exists/, err)
      end

      should("change a level and log it") do
        assert_difference(-> { ModAction.where(action: "user_level_change").count }, 1) do
          run_cli("users:level", "someone", "moderator")
        end

        assert_equal(User::Levels::MODERATOR, @user.reload.level)
      end

      should("reject unknown levels") do
        _, err, status = run_cli("users:level", "someone", "emperor")

        assert_equal(1, status)
        assert_match(/Unknown level emperor/, err)
      end

      should("change a password") do
        run_cli("users:password", "someone", "--password", "newpass1")

        assert(User.authenticate("someone", "newpass1"))
      end

      should("rename a user") do
        run_cli("users:rename", "someone", "someone_else")

        assert_equal("someone_else", @user.reload.name)
      end

      should("delete a user") do
        assert_difference(-> { ModAction.where(action: "user_delete", creator: User.system).count }, 1) do
          run_cli("users:delete", "someone", "--yes")
        end

        assert_equal("user_#{@user.id}", @user.reload.name)
        assert_equal("*LK*", @user.bcrypt_password_hash)
      end

      should("not delete without confirmation") do
        _, err, status = run_cli("users:delete", "someone")

        assert_equal(1, status)
        assert_match(/Pass --yes/, err)
        assert_equal("someone", @user.reload.name)
      end

      should("not delete the system user") do
        _, err, status = run_cli("users:delete", User.system.name, "--yes")

        assert_equal(1, status)
        assert_match(/can't be deleted/, err)
      end

      should("ban and unban a user") do
        run_cli("users:ban", "someone", "--reason", "spam", "--duration", "3")

        assert_predicate(@user.reload, :is_banned?)

        run_cli("users:unban", "someone")

        assert_not(@user.reload.is_banned?)
      end
    end

    context("config") do
      should("show and change an option") do
        out, = run_cli("config:set", "records_per_page", "50")

        assert_match(/records_per_page = 50/, out)
        assert_equal(50, AdminConfig.instance.records_per_page)
        assert_equal("50\n", run_cli("config:get", "records_per_page").first)
      end

      should("reject unknown options") do
        _, err, status = run_cli("config:set", "nonexistent", "1")

        assert_equal(1, status)
        assert_match(/Unknown option nonexistent/, err)
      end
    end

    context("features") do
      should("turn features off and on") do
        run_cli("features:disable", "pools")

        assert_not(Feature.enabled?(:pools))

        run_cli("features:enable", "pools")

        assert(Feature.enabled?(:pools))
      end

      should("reject unknown features") do
        _, err, status = run_cli("features:enable", "teleporting")

        assert_equal(1, status)
        assert_match(/Unknown feature/, err)
      end
    end
  end
end
