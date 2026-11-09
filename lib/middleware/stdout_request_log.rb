# frozen_string_literal: true

module Middleware
  # Prints one short line per request to stdout so the container's output shows request volume:
  # [request id][ip][duration] method path?query status
  # The query string stays url encoded so the line has no spaces, with things like api keys filtered out.
  # Lines are colored by how long the request took, or bold magenta when it timed out, unless NO_COLOR is set.
  class StdoutRequestLog
    MAX_QUERY_LENGTH = 500

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
        line = "#{self.class.prefix(env, "#{duration}ms")} #{request.request_method} #{request.path}#{query(env)} #{status}"
        # syswrite skips ruby's buffering, which would otherwise hold lines back when stdout isn't a tty
        @io.syswrite("#{colorize(line, duration, status)}\n")
      end

      [status, headers, body]
    end

    # [request id][ip][time], shared with the lines Middleware::LoadShedding logs
    def self.prefix(env, time)
      request = ActionDispatch::Request.new(env)
      "[#{env['action_dispatch.request_id'] || '-'}][#{request.remote_ip.presence || '-'}][#{time}]"
    end

    def colorize(line, duration, status = nil)
      return line unless @color
      "\e[#{color(duration, status)}m#{line}\e[0m"
    end

    # ansi colors
    def color(duration, status)
      # ApplicationController answers RequestTimeoutError with a 504
      return "1;35" if status.to_i == 504 # bold magenta
      case duration
      when 2000.. then "31" # red
      when 500.. then "33" # yellow
      when ..25 then "34" # blue
      else "32" # green
      end
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
