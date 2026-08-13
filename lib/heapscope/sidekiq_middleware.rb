# frozen_string_literal: true

module HeapScope
  # Optional Sidekiq server middleware. Does not require Sidekiq at load time.
  class SidekiqMiddleware
    def initialize(options = {})
      @sample_rate = options.fetch(:sample_rate, 0.05)
      @force_gc = options.fetch(:force_gc, false)
      @mode = options.fetch(:mode, :lightweight)
      @on_report = options[:on_report]
    end

    def call(worker, job, queue)
      return yield if @sample_rate <= 0 || rand > @sample_rate

      result = nil
      report = HeapScope.measure(
        force_gc: @force_gc,
        mode: @mode,
        metadata: {
          kind: "sidekiq_job",
          worker: worker.class.name,
          queue: queue,
          jid: job["jid"],
          pid: Process.pid
        }
      ) do
        result = yield
        true
      end

      @on_report&.call(report)
      result
    end
  end
end
