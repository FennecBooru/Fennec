# frozen_string_literal: true

require("test_helper")

class ExceptionLogTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  context("An exception log") do
    should("log for query timeout errors with bind parameters") do
      Post.connection.execute("SET STATEMENT_TIMEOUT = 50")
      e = assert_raises(ActiveRecord::QueryCanceled) do
        Post.from("pg_sleep(1), posts").where(description: "bind param").count
      end
      log = ExceptionLog.add!(e, user_id: 1, request: ActionDispatch::TestRequest.new("rack.input" => "abc", "REMOTE_ADDR" => "127.0.0.1"))

      assert_equal(["bind param"], log.extra_params["sql"]["binds"])
    ensure
      Post.connection.execute("SET STATEMENT_TIMEOUT = 3000")
      ExceptionLog.destroy_all
    end

    context("prune!") do
      setup do
        @old = ExceptionLog.add!(StandardError.new("old"))
        @old.update_columns(created_at: 10.days.ago)
        @new = ExceptionLog.add!(StandardError.new("new"))
      end

      teardown do
        ExceptionLog.destroy_all
      end

      should("delete logs older than the retention") do
        stub_admin_config(:exception_log_retention, 7)
        ExceptionLog.prune!

        assert_equal([@new.id], ExceptionLog.pluck(:id))
      end

      should("keep everything when the retention is 0") do
        stub_admin_config(:exception_log_retention, 0)
        ExceptionLog.prune!

        assert_equal(2, ExceptionLog.count)
      end
    end

    context("discord webhook") do
      setup do
        Fennec.config.stubs(:discord_exceptions_webhook_url).returns("https://discord.test/webhook")
        Rails.cache.clear
      end

      teardown do
        ExceptionLog.destroy_all
      end

      should("post the exception") do
        request = stub_request(:post, "https://discord.test/webhook").with { |req| JSON.parse(req.body)["embeds"][0]["title"] == "ArgumentError" }
        perform_enqueued_jobs(only: ExceptionWebhookJob) do
          ExceptionLog.add!(ArgumentError.new("bad"), source: "test")
        end

        assert_requested(request)
      end

      should("not enqueue without a webhook") do
        Fennec.config.stubs(:discord_exceptions_webhook_url).returns(nil)

        assert_no_enqueued_jobs(only: ExceptionWebhookJob) do
          ExceptionLog.add!(ArgumentError.new("bad"), source: "test")
        end
      end
    end
  end
end
