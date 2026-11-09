# frozen_string_literal: true

require_relative("plain_page")

module Middleware
  # Turns away requests that waited too long for a worker, so an overloaded app answers quickly instead of working
  # through a backlog of requests whose clients have already given up. Anonymous requests are turned away first,
  # logged in users and api requests are only turned away when the backlog is far worse.
  #
  # The wait is measured from the X-Request-Start header, which nginx sets. Requests without it are never turned away.
  class LoadShedding
    # io gets a line per dropped request, only in production like Middleware::StdoutRequestLog
    def initialize(app, anonymous_ms: Fennec.config.load_shedding_anonymous_ms, user_ms: Fennec.config.load_shedding_user_ms, io: Rails.env.production? ? $stdout : nil)
      @app = app
      @anonymous_ms = anonymous_ms
      @user_ms = user_ms
      @io = io
    end

    def call(env)
      return @app.call(env) if env["PATH_INFO"] == "/up"
      waited = queue_time_ms(env)
      return @app.call(env) if waited.nil?

      priority = RequestIdentity.claims_user?(env)
      limit = priority ? @user_ms : @anonymous_ms
      return @app.call(env) if limit.to_i <= 0 || waited < limit

      kind = priority ? "user" : "anonymous"
      Yabeda.requests.shed.increment({ priority: kind }) if Metrics.enabled?
      @io&.syswrite("#{StdoutRequestLog.prefix(env, "waited #{waited.round(1)}ms")} DROPPED #{kind}\n")
      overloaded(env)
    end

    # nginx's $msec is seconds with millisecond precision, other proxies send milliseconds or microseconds
    def queue_time_ms(env)
      value = env["HTTP_X_REQUEST_START"].to_s.delete_prefix("t=")
      return nil unless value.match?(/\A\d+(\.\d+)?\z/)
      started = value.to_f
      started /= 1000 while started > 100_000_000_000 # past year 5138 in seconds, so it's ms or µs
      [(Time.now.to_f - started) * 1000, 0].max
    end

    def overloaded(env)
      headers = { "retry-after" => "10", "cache-control" => "no-store" }
      if env["PATH_INFO"].end_with?(".json") || env["HTTP_ACCEPT"].to_s.include?("application/json")
        [503, headers.merge("content-type" => "application/json"), [{ success: false, message: "The site is overloaded, try again in a moment" }.to_json]]
      else
        [503, headers.merge("content-type" => "text/html; charset=utf-8"), [PAGE]]
      end
    end

    PAGE = PlainPage.render("The site is overloaded", "<p>We're getting more requests than we can handle right now. Try again in a moment, logged in users are let through first.</p>")
  end
end
