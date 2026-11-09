# frozen_string_literal: true

require("test_helper")

module Middleware
  class AnonymousSearchLimitsTest < ActiveSupport::TestCase
    def setup
      @middleware = AnonymousSearchLimits.new(->(_env) { [200, {}, ["ok"]] })
      stub_admin_config(:anonymous_hard_tag_limit, 2)
      stub_admin_config(:anonymous_restricted_search_terms, "fav")
    end

    def env(url, session: {}, **)
      env = Rack::MockRequest.env_for(url, **)
      env["rack.session"] = session.with_indifferent_access
      env
    end

    should("reject anonymous searches over the tag limit") do
      status, headers, body = @middleware.call(env("/posts?tags=a+b+c"))

      assert_equal(422, status)
      assert_equal("text/html; charset=utf-8", headers["content-type"])
      assert_includes(body.join, "Your query exceeds the limit")
    end

    should("reject anonymous searches using a restricted term") do
      status, _headers, body = @middleware.call(env("/posts.json?tags=fav%3Abob"))

      assert_equal(422, status)
      assert_equal({ "success" => false, "message" => "you cannot use the term: fav:bob" }, JSON.parse(body.join))
    end

    should("let allowed searches through") do
      assert_equal(200, @middleware.call(env("/posts?tags=a+b")).first)
      assert_equal(200, @middleware.call(env("/posts")).first)
    end

    should("let users through") do
      assert_equal(200, @middleware.call(env("/posts?tags=a+b+c", session: { user_id: 1 })).first)
      assert_equal(200, @middleware.call(env("/posts.json?tags=fav%3Abob", "HTTP_AUTHORIZATION" => "Basic abc")).first)
    end

    should("only check post searches") do
      assert_equal(200, @middleware.call(env("/posts/1?tags=a+b+c")).first)
      assert_equal(200, @middleware.call(env("/posts?tags=a+b+c", method: "POST")).first)
    end

    should("escape the message") do
      stub_admin_config(:anonymous_restricted_search_terms, "<b>")

      assert_not_includes(@middleware.call(env("/posts?tags=%3Cb%3E%3Ax")).last.join, "<b>:x")
    end
  end
end
