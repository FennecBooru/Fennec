# frozen_string_literal: true

require("test_helper")

module Middleware
  class StdoutRequestLogTest < ActiveSupport::TestCase
    def setup
      @io = StringIO.new
    end

    should("log one line per request") do
      middleware = StdoutRequestLog.new(->(_env) { [201, {}, [""]] }, io: @io)

      middleware.call(Rack::MockRequest.env_for("/posts", :method => "POST", "REMOTE_ADDR" => "1.2.3.4"))

      lines = @io.string.lines

      assert_equal(1, lines.size)
      assert_match(%r{\A\S+ POST /posts 201 [\d.]+ms 1\.2\.3\.4\n\z}, lines.first)
    end

    should("log the query string with sensitive values filtered") do
      middleware = StdoutRequestLog.new(->(_env) { [200, {}, [""]] }, io: @io)

      middleware.call(Rack::MockRequest.env_for("/posts.json?tags=fox+rating%3As&login=bob&api_key=secret&page=2"))

      assert_match(%r{ GET /posts\.json\?tags=fox\+rating%3As&login=bob&api_key=\[FILTERED\]&page=2 200 }, @io.string)
      assert_no_match(/secret/, @io.string)
    end

    should("truncate long query strings") do
      middleware = StdoutRequestLog.new(->(_env) { [200, {}, [""]] }, io: @io)

      middleware.call(Rack::MockRequest.env_for("/posts?tags=#{'a' * 2000}"))

      assert_operator(@io.string.length, :<, 700)
    end

    should("log a 500 when the app raises") do
      middleware = StdoutRequestLog.new(->(_env) { raise("boom") }, io: @io)

      assert_raises(RuntimeError) { middleware.call(Rack::MockRequest.env_for("/test")) }
      assert_match(%r{ GET /test 500 }, @io.string)
    end

    should("skip the healthcheck") do
      middleware = StdoutRequestLog.new(->(_env) { [200, {}, [""]] }, io: @io)

      middleware.call(Rack::MockRequest.env_for("/up"))

      assert_equal("", @io.string)
    end
  end
end
