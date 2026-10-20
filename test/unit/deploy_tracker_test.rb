# frozen_string_literal: true

require("test_helper")

class DeployTrackerTest < ActiveSupport::TestCase
  def last_log(action)
    StaffAuditLog.where(action: action).order(id: :desc).first
  end

  context("DeployTracker") do
    setup do
      DeployTracker.enabled = true
    end

    teardown do
      DeployTracker.enabled = nil
    end

    should("log the version once per version") do
      Fennec.config.stubs(:version).returns("aaaaaaaa")
      DeployTracker.version!
      DeployTracker.version!

      assert_equal(1, StaffAuditLog.where(action: "version_bump").count)
      log = last_log("version_bump")

      assert_equal(User.system.id, log.user_id)
      assert_equal({ "old_version" => nil, "new_version" => "aaaaaaaa" }, log.data)

      Fennec.config.stubs(:version).returns("bbbbbbbb")
      DeployTracker.version!

      assert_equal({ "old_version" => "aaaaaaaa", "new_version" => "bbbbbbbb" }, last_log("version_bump").data)
      assert_match(/Updated the site from .*aaaaaaaa.* to .*bbbbbbbb/, last_log("version_bump").format_text)
    end

    should("log migrations") do
      migration = Class.new(ActiveRecord::Migration[8.1]) do
        def change
        end
      end.new("TestMigration", 20_990_101_000_000)
      migration.migrate(:up)
      log = last_log("migration_run")

      assert_equal({ "version" => "20990101000000", "name" => "TestMigration", "direction" => "up" }, log.data)
      assert_equal("Ran migration 20990101000000 TestMigration (up)", log.format_text)
    end

    should("log fixes") do
      path = Rails.root.join("tmp/9999_deploy_tracker_test.rb")
      File.write(path, "# frozen_string_literal: true\n")
      YiffSpace::FixTracker.run!(path)

      assert_equal("Ran fix 9999_deploy_tracker_test", last_log("fix_run").format_text)
    ensure
      FileUtils.rm_f(path)
    end

    should("not log when disabled") do
      DeployTracker.enabled = false
      DeployTracker.fix!("1_test")

      assert_nil(last_log("fix_run"))
    end
  end
end
