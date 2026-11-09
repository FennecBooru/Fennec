# frozen_string_literal: true

module Middleware
  # Rejects post searches that break the anonymous limits (TagQuery.anonymous_violation) before they reach the app, so
  # a scraper sending them costs next to nothing. The app still checks them, this only answers sooner.
  class AnonymousSearchLimits
    PATHS = %w[/posts /posts.json /posts/random /posts/random.json].freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) unless env["REQUEST_METHOD"] == "GET" && PATHS.include?(env["PATH_INFO"])
      tags = Rack::Request.new(env).GET["tags"]
      return @app.call(env) unless tags.is_a?(String) && tags.present?
      return @app.call(env) if RequestIdentity.claims_user?(env)

      error = TagQuery.anonymous_violation(tags)
      return @app.call(env) if error.nil?
      rejected(env, error.message)
    end

    def rejected(env, message)
      if env["PATH_INFO"].end_with?(".json") || env["HTTP_ACCEPT"].to_s.include?("application/json")
        [422, { "content-type" => "application/json", "cache-control" => "no-store" }, [{ success: false, message: message }.to_json]]
      else
        body = <<~HTML
          <!doctype html>
          <html lang="en">
          <head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Search not allowed</title></head>
          <body style="font-family: sans-serif; max-width: 40em; margin: 4em auto; padding: 0 1em">
          <h1>Search not allowed</h1>
          <p>#{ERB::Util.html_escape(message.upcase_first)}. <a href="/session/new">Log in</a> to search without this limit.</p>
          </body>
          </html>
        HTML
        [422, { "content-type" => "text/html; charset=utf-8", "cache-control" => "no-store" }, [body]]
      end
    end
  end
end
