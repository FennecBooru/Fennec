# frozen_string_literal: true

require("test_helper")

module Middleware
  class StdoutRequestLogTest < ActiveSupport::TestCase
    def setup
      @io = StringIO.new
    end

    should("log one line per request") do
      middleware = StdoutRequestLog.new(->(_env) { [201, {}, [""]] }, io: @io, color: false)

      middleware.call(Rack::MockRequest.env_for("/posts", :method => "POST", "REMOTE_ADDR" => "1.2.3.4", "action_dispatch.request_id" => "abc123"))

      lines = @io.string.lines

      assert_equal(1, lines.size)
      assert_match(%r{\A\[abc123\]\[1\.2\.3\.4\]\[[\d.]+ms\] POST /posts 201\n\z}, lines.first)
    end

    should("log the query string with sensitive values filtered") do
      middleware = StdoutRequestLog.new(->(_env) { [200, {}, [""]] }, io: @io, color: false)

      middleware.call(Rack::MockRequest.env_for("/posts.json?tags=fox+rating%3As&login=bob&api_key=secret&page=2"))

      assert_match(%r{ GET /posts\.json\?tags=fox\+rating%3As&login=bob&api_key=\[FILTERED\]&page=2 200\n}, @io.string)
      assert_no_match(/secret/, @io.string)
    end

    should("truncate long query strings") do
      middleware = StdoutRequestLog.new(->(_env) { [200, {}, [""]] }, io: @io, color: false)

      middleware.call(Rack::MockRequest.env_for("/posts?tags=#{'a' * 2000}"))

      assert_operator(@io.string.length, :<, 700)
    end

    should("log a 500 when the app raises") do
      middleware = StdoutRequestLog.new(->(_env) { raise("boom") }, io: @io, color: false)

      assert_raises(RuntimeError) { middleware.call(Rack::MockRequest.env_for("/test")) }
      assert_match(%r{ GET /test 500\n}, @io.string)
    end

    should("color lines by how long the request took") do
      middleware = StdoutRequestLog.new(->(_env) { [200, {}, [""]] }, io: @io, color: true)

      assert_equal("\e[34minstant\e[0m", middleware.colorize("instant", 25.0))
      assert_equal("\e[32mfast\e[0m", middleware.colorize("fast", 26.0))
      assert_equal("\e[32mfast\e[0m", middleware.colorize("fast", 499.9))
      assert_equal("\e[33mslow\e[0m", middleware.colorize("slow", 500.0))
      assert_equal("\e[31mslower\e[0m", middleware.colorize("slower", 2000.0))
      assert_equal("\e[1;35mtimeout\e[0m", middleware.colorize("timeout", 10_000.0, 504))
      assert_equal("\e[1;35mtimeout\e[0m", middleware.colorize("timeout", 3.0, 504))

      middleware.call(Rack::MockRequest.env_for("/posts"))

      assert_match(%r{\A\e\[[\d;]+m\[-\]\[[^\]]+\]\[[\d.]+ms\] GET /posts 200\e\[0m\n\z}, @io.string)
    end

    should("skip the healthcheck") do
      middleware = StdoutRequestLog.new(->(_env) { [200, {}, [""]] }, io: @io, color: false)

      middleware.call(Rack::MockRequest.env_for("/up"))

      assert_equal("", @io.string)
    end
  end
end
