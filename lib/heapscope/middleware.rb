# frozen_string_literal: true

module HeapScope
  # Opt-in Rack middleware. Lightweight sampling only — never full heap on every request.
  class Middleware
    def initialize(app, sample_rate: 0.01, force_gc: false, mode: :lightweight, on_report: nil)
      @app = app
      @sample_rate = sample_rate
      @force_gc = force_gc
      @mode = mode
      @on_report = on_report
    end

    def call(env)
      return @app.call(env) if @sample_rate <= 0 || rand > @sample_rate

      status = headers = body = nil
      report = HeapScope.measure(
        force_gc: @force_gc,
        mode: @mode,
        metadata: {
          kind: "rack_request",
          path: env["PATH_INFO"],
          method: env["REQUEST_METHOD"],
          pid: Process.pid
        }
      ) do
        status, headers, body = @app.call(env)
        true
      end
      @on_report&.call(report)
      [status, headers, body]
    end
  end
end
