# frozen_string_literal: true

require("test_helper")

module Middleware
  class LoadSheddingTest < ActiveSupport::TestCase
    def setup
      @middleware = LoadShedding.new(->(_env) { [200, {}, ["ok"]] }, anonymous_ms: 1000, user_ms: 5000)
    end

    def env(path = "/posts", waited: nil, header: nil, session: {}, **)
      header ||= "t=#{format('%.3f', Time.now.to_f - waited)}" if waited
      env = Rack::MockRequest.env_for(path, **)
      env["HTTP_X_REQUEST_START"] = header if header
      env["rack.session"] = session.with_indifferent_access
      env
    end

    should("let requests through without the header") do
      assert_equal(200, @middleware.call(env).first)
    end

    should("let anonymous requests through when they didn't wait long") do
      assert_equal(200, @middleware.call(env(waited: 0.5)).first)
    end

    should("turn away anonymous requests that waited too long") do
      status, headers, body = @middleware.call(env(waited: 2))

      assert_equal(503, status)
      assert_equal("10", headers["retry-after"])
      assert_includes(body.join, "overloaded")
    end

    should("log the dropped request with how long it waited") do
      io = StringIO.new
      middleware = LoadShedding.new(->(_env) { [200, {}, ["ok"]] }, anonymous_ms: 1000, user_ms: 5000, io: io)
      request = env(:waited => 2, "REMOTE_ADDR" => "1.2.3.4")
      request["action_dispatch.request_id"] = "abc123"
      middleware.call(request)

      assert_match(/\A\[abc123\]\[1\.2\.3\.4\]\[waited \d+\.\dms\] DROPPED anonymous\n\z/, io.string)
    end

    should("answer json requests with json") do
      status, _headers, body = @middleware.call(env("/posts.json", waited: 2))

      assert_equal(503, status)
      assert_includes(body.join, '"success":false')
    end

    should("let logged in users wait longer") do
      assert_equal(200, @middleware.call(env(waited: 2, session: { user_id: 1 })).first)
      assert_equal(503, @middleware.call(env(waited: 6, session: { user_id: 1 })).first)
    end

    should("let api requests wait longer") do
      assert_equal(200, @middleware.call(env(:waited => 2, "HTTP_AUTHORIZATION" => "Basic abc")).first)
      assert_equal(200, @middleware.call(env("/posts.json?login=a&api_key=b", waited: 2)).first)
    end

    should("understand milliseconds and microseconds") do
      assert_equal(503, @middleware.call(env(header: "t=#{((Time.now.to_f - 2) * 1000).round}")).first)
      assert_equal(503, @middleware.call(env(header: "t=#{((Time.now.to_f - 2) * 1_000_000).round}")).first)
    end

    should("ignore unreadable headers and the healthcheck") do
      assert_equal(200, @middleware.call(env(header: "garbage")).first)
      assert_equal(200, @middleware.call(env("/up", waited: 60)).first)
    end

    should("be turned off by a zero limit") do
      middleware = LoadShedding.new(->(_env) { [200, {}, ["ok"]] }, anonymous_ms: 0, user_ms: 0)

      assert_equal(200, middleware.call(env(waited: 60)).first)
    end
  end
end
