# frozen_string_literal: true

module Middleware
  # Prints one short line per request to stdout so the container's output shows request volume.
  # The query string is left out since it can contain things like api keys.
  class StdoutRequestLog
    def initialize(app, io: $stdout)
      @app = app
      @io = io
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
        @io.syswrite("#{Time.now.utc.iso8601(3)} #{request.request_method} #{request.path} #{status} #{duration}ms #{request.remote_ip}\n")
      end

      [status, headers, body]
    end
  end
end
