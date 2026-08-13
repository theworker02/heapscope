# frozen_string_literal: true

module HeapScope
  # One-shot probe that prints an executive scorecard for a workload.
  class Probe
    Result = Struct.new(:report, :scorecard, :printed, keyword_init: true)

    def self.run(title: "probe", force_gc: true, mode: :lightweight, print: true, &block)
      new(title: title, force_gc: force_gc, mode: mode, print: print).run(&block)
    end

    def initialize(title:, force_gc:, mode:, print:)
      @title = title
      @force_gc = force_gc
      @mode = mode
      @print = print
    end

    def run(&)
      raise ArgumentError, "block required" unless block_given?

      report = HeapScope.measure(force_gc: @force_gc, mode: @mode, metadata: { kind: "probe", title: @title }, &)
      scorecard = Scorecard.from_report(report, title: @title)
      puts scorecard.to_text if @print && !HeapScope.config.quiet
      Result.new(report: report, scorecard: scorecard, printed: @print)
    end
  end

  # Compact executive summary for CI logs and consoles.
  class Scorecard
    attr_reader :title, :verdict, :rss_delta, :live_delta, :retention_ratio,
                :top_suspects, :finding_codes, :healthy

    def self.from_report(report, title: "HeapScope")
      new(
        title: title,
        healthy: report.healthy?,
        verdict: report.healthy? ? "HEALTHY" : "ATTENTION",
        rss_delta: report.diff&.rss_delta,
        live_delta: report.diff&.heap_live_delta,
        retention_ratio: report.diff&.retention_ratio,
        top_suspects: Array(report.suspects).first(3).map { |s| "#{s[:name]}(+#{s[:delta_count]}/#{s[:severity]})" },
        finding_codes: report.findings.map { |f| "#{f.code}:#{f.severity}" }
      )
    end

    def initialize(**attrs)
      attrs.each { |k, v| instance_variable_set("@#{k}", v) }
    end

    def to_h
      {
        title: title,
        verdict: verdict,
        healthy: healthy,
        rss_delta: rss_delta,
        live_delta: live_delta,
        retention_ratio: retention_ratio,
        top_suspects: top_suspects,
        finding_codes: finding_codes
      }
    end

    def to_text
      lines = []
      lines << "┌─ HeapScope scorecard ─────────────────────────"
      lines << "│ #{title}"
      lines << "│ Verdict: #{verdict}"
      lines << "│ RSS Δ: #{fmt_bytes(rss_delta)}   Live slots Δ: #{live_delta || 'n/a'}"
      lines << "│ Retention: #{retention_ratio ? format('%.2f%%', retention_ratio * 100) : 'n/a'}"
      lines << "│ Suspects: #{top_suspects.empty? ? 'none' : top_suspects.join(', ')}"
      lines << "│ Findings: #{finding_codes.empty? ? 'none' : finding_codes.join(', ')}"
      lines << "└───────────────────────────────────────────────"
      lines.join("\n")
    end

    private

    def fmt_bytes(n)
      return "n/a" if n.nil?

      format("%+.2f MB", n.to_f / (1024 * 1024))
    end
  end
end
