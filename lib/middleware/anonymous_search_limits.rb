# frozen_string_literal: true

require_relative("plain_page")

module Middleware
  # Rejects post searches that break the anonymous limits (TagQuery.anonymous_violation) before they reach the app, so
  # a scraper sending them costs next to nothing. The app still checks them, this only answers sooner.
  class AnonymousSearchLimits
    SEARCH_PATHS = %w[/posts /posts.json /posts/random /posts/random.json].freeze
    # post pages show the search they came from, and show_seq searches with it for the next and previous posts
    POST_PATH = %r{\A/posts/\d+(?:\.json)?\z}
    SEQ_PATH = %r{\A/posts/\d+/show_seq(?:\.json)?\z}

    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) unless env["REQUEST_METHOD"] == "GET"
      tags = search(env)
      return @app.call(env) unless tags.is_a?(String) && tags.present?
      return @app.call(env) if RequestIdentity.claims_user?(env)

      error = TagQuery.anonymous_violation(tags)
      return @app.call(env) if error.nil?
      rejected(env, error.message)
    end

    def search(env)
      path = env["PATH_INFO"]
      return unless SEARCH_PATHS.include?(path) || POST_PATH.match?(path) || SEQ_PATH.match?(path)
      params = Rack::Request.new(env).GET
      return params["tags"] if SEARCH_PATHS.include?(path)
      return params["q"] if POST_PATH.match?(path)
      params["q"].presence || params["tags"]
    end

    def rejected(env, message)
      if env["PATH_INFO"].end_with?(".json") || env["HTTP_ACCEPT"].to_s.include?("application/json")
        [422, { "content-type" => "application/json", "cache-control" => "no-store" }, [{ success: false, message: message }.to_json]]
      else
        body = PlainPage.render("Search not allowed", "<p>#{ERB::Util.html_escape(message.upcase_first)}. <a href=\"/session/new\">Log in</a> to search without this limit.</p>")
        [422, { "content-type" => "text/html; charset=utf-8", "cache-control" => "no-store" }, [body]]
      end
    end
  end
end
