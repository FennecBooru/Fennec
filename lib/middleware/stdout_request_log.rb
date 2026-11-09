# frozen_string_literal: true

module Middleware
  # Prints one short line per request to stdout so the container's output shows request volume.
  # The query string stays url encoded so the line has no spaces, with things like api keys filtered out.
  class StdoutRequestLog
    MAX_QUERY_LENGTH = 500

    def initialize(app, io: $stdout)
      @app = app
      @io = io
      @filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    end

    def call(env)
      return @app.call(env) if env["PATH_INFO"] == "/up"

      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      status = 500
      begin
        status, headers, body = @app.call(env)
      ensure
        duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round(1)
        request = ActionDispatch::Request.new(env)
        # syswrite skips ruby's buffering, which would otherwise hold lines back when stdout isn't a tty
        @io.syswrite("#{Time.now.utc.iso8601(3)} #{request.request_method} #{request.path}#{query(env)} #{status} #{duration}ms #{request.remote_ip}\n")
      end

      [status, headers, body]
    end

    def query(env)
      query = env["QUERY_STRING"].to_s
      return "" if query.empty?
      pairs = query.split("&").map do |pair|
        key, value = pair.split("=", 2)
        name = CGI.unescape(key.to_s)
        value && @filter.filter(name => value)[name] != value ? "#{key}=[FILTERED]" : pair
      end
      "?#{pairs.join('&').truncate(MAX_QUERY_LENGTH)}"
    rescue ArgumentError
      "?[invalid]"
    end
  end
end
