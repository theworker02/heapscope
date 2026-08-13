# frozen_string_literal: true

module HeapScope
  # In-process sampling monitor with optional anomaly alerts.
  # Uses a low-priority background thread.
  class Monitor
    Sample = Struct.new(:at, :snapshot, keyword_init: true)
    Alert = Struct.new(:at, :kind, :message, :rss_delta, :live_delta, keyword_init: true)

    attr_reader :samples, :interval, :mode, :alerts

    def self.start(interval: 10, mode: :lightweight, max_samples: 1_000,
                   alert: false, rss_alert_bytes: 25 * 1024 * 1024, live_alert_slots: 80_000)
      new(
        interval: interval,
        mode: mode,
        max_samples: max_samples,
        alert: alert,
        rss_alert_bytes: rss_alert_bytes,
        live_alert_slots: live_alert_slots
      ).tap(&:start)
    end

    def initialize(interval: 10, mode: :lightweight, max_samples: 1_000,
                   alert: false, rss_alert_bytes: 25 * 1024 * 1024, live_alert_slots: 80_000)
      @interval = interval
      @mode = mode
      @max_samples = max_samples
      @alert = alert
      @rss_alert_bytes = rss_alert_bytes
      @live_alert_slots = live_alert_slots
      @samples = []
      @alerts = []
      @thread = nil
      @stop = false
      @collector = Collector.new
    end

    def alert?
      @alert
    end

    def start
      return self if @thread&.alive?

      @stop = false
      @thread = Thread.new do
        Thread.current.name = "heapscope-monitor" if Thread.current.respond_to?(:name=)
        Thread.current.abort_on_exception = false
        until @stop
          begin
            snap = @collector.capture(mode: @mode, metadata: { monitor: true })
            sample = Sample.new(at: Time.now.utc, snapshot: snap)
            maybe_alert!(sample)
            @samples << sample
            @samples.shift if @samples.size > @max_samples
          rescue StandardError => e
            HeapScope.config.log(:debug, "monitor sample failed: #{e.message}")
          end
          sleep @interval
        end
      end
      self
    end

    def stop
      @stop = true
      @thread&.join(2)
      @thread = nil
      finish_report
    end

    def finish_report
      if samples.empty?
        return Report.new(
          summary: { healthy: true, samples: 0 },
          metadata: { kind: "monitor", alerts: [] }
        )
      end

      session_like = samples.map(&:snapshot)
      first = session_like.first
      last = session_like.last
      diff = Diff.new(first, last)
      analysis = Analyzer.new.analyze_diff(diff)
      series = build_timeline
      alert_payload = alerts.map(&:to_h)
      Report.from_diff(
        diff,
        analysis: analysis,
        metadata: {
          kind: "monitor",
          timeline: series,
          alerts: alert_payload,
          alert_count: alert_payload.size
        }
      )
    end

    private

    def maybe_alert!(sample)
      return unless @alert
      return if samples.empty?

      prev = samples.last.snapshot
      rss_delta = safe_delta(sample.snapshot.rss_bytes, prev.rss_bytes)
      live_delta = safe_delta(sample.snapshot.heap_live_slots, prev.heap_live_slots)

      if rss_delta && rss_delta >= @rss_alert_bytes
        record_alert!(
          :rss_spike,
          "RSS rose by #{rss_delta} bytes between samples (threshold #{@rss_alert_bytes}).",
          rss_delta: rss_delta,
          live_delta: live_delta
        )
      end

      return unless live_delta && live_delta >= @live_alert_slots

      record_alert!(
        :live_slots_spike,
        "Heap live slots rose by #{live_delta} between samples (threshold #{@live_alert_slots}).",
        rss_delta: rss_delta,
        live_delta: live_delta
      )
    end

    def record_alert!(kind, message, rss_delta:, live_delta:)
      alert = Alert.new(
        at: Time.now.utc.iso8601,
        kind: kind,
        message: message,
        rss_delta: rss_delta,
        live_delta: live_delta
      )
      @alerts << alert
      HeapScope.config.log(:info, "monitor alert: #{kind} — #{message}")
      warn("[HeapScope watch] #{kind}: #{message}") if $stderr.tty? && !HeapScope.config.quiet
    end

    def safe_delta(after_v, before_v)
      return nil if after_v.nil? || before_v.nil?

      after_v - before_v
    end

    def build_timeline
      samples.map do |s|
        top = s.snapshot.top_classes(1).first
        {
          time: s.at.iso8601,
          rss_bytes: s.snapshot.rss_bytes,
          live_slots: s.snapshot.heap_live_slots,
          top_class: top && top[:name]
        }
      end
    end
  end
end
