# frozen_string_literal: true

module Middleware
  # Prints one short line per request to stdout so the container's output shows request volume.
  # The query string stays url encoded so the line has no spaces, with things like api keys filtered out.
  # Lines are colored by how long the request took, unless NO_COLOR is set.
  class StdoutRequestLog
    MAX_QUERY_LENGTH = 500
    # [up to this many ms, ansi color]
    COLORS = [
      [25, "34"], # blue
      [200, "32"], # green
      [1000, "33"], # yellow
      [5000, "31"], # red
      [Float::INFINITY, "1;35"], # bold magenta
    ].freeze

    def initialize(app, io: $stdout, color: ENV["NO_COLOR"].blank?)
      @app = app
      @io = io
      @color = color
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
        line = "#{Time.now.utc.iso8601(3)} #{request.request_method} #{request.path}#{query(env)} #{status} #{duration}ms #{request.remote_ip}"
        @io.syswrite("#{colorize(line, duration)}\n")
      end

      [status, headers, body]
    end

    def colorize(line, duration)
      return line unless @color
      "\e[#{COLORS.find { |limit, _| duration < limit }.last}m#{line}\e[0m"
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
