# frozen_string_literal: true

module HeapScope
  # Explicit memory budgets for CI and regression tests. Integers only — no AS core_ext required.
  class Budget
    PRESETS = {
      rails_request: {
        max_retained_objects: 5_000,
        max_retained_bytes: 8 * 1024 * 1024,
        max_retention_ratio: 0.15,
        max_rss_growth: 20 * 1024 * 1024,
        max_heap_live_growth: 50_000,
        severity_threshold: :high
      },
      sidekiq_job: {
        max_retained_objects: 10_000,
        max_retained_bytes: 16 * 1024 * 1024,
        max_retention_ratio: 0.20,
        max_rss_growth: 50 * 1024 * 1024,
        max_heap_live_growth: 100_000,
        severity_threshold: :high
      },
      ci_strict: {
        max_retained_objects: 500,
        max_retained_bytes: 2 * 1024 * 1024,
        max_retention_ratio: 0.05,
        max_rss_growth: 5 * 1024 * 1024,
        max_heap_live_growth: 5_000,
        severity_threshold: :medium
      }
    }.freeze

    attr_reader :max_retained_objects, :max_retained_bytes, :max_retention_ratio,
                :max_rss_growth, :max_heap_live_growth, :severity_threshold, :preset_name

    def self.preset(name)
      key = name.to_sym
      attrs = PRESETS[key]
      raise ArgumentError, "Unknown budget preset: #{name} (#{PRESETS.keys.join(', ')})" unless attrs

      new(**attrs, preset_name: key)
    end

    def self.presets
      PRESETS.keys
    end

    def initialize(max_retained_objects: nil, max_retained_bytes: nil,
                   max_retention_ratio: nil, max_rss_growth: nil,
                   max_heap_live_growth: nil, severity_threshold: :high,
                   preset_name: nil)
      @max_retained_objects = max_retained_objects
      @max_retained_bytes = max_retained_bytes
      @max_retention_ratio = max_retention_ratio
      @max_rss_growth = max_rss_growth
      @max_heap_live_growth = max_heap_live_growth
      @severity_threshold = severity_threshold
      @preset_name = preset_name
    end

    def evaluate(report)
      violations = []
      diff = report.diff

      if max_retained_objects && diff
        surviving = diff.surviving_estimate || report.classes.sum { |c| [c[:delta_count].to_i, 0].max }
        violations << "Retained objects #{surviving} exceed budget #{max_retained_objects}" if surviving && surviving > max_retained_objects
      end

      if max_retained_bytes && diff
        bytes = diff.heap_bytes_estimate_delta
        violations << "Retained bytes #{bytes} exceed budget #{max_retained_bytes}" if bytes > max_retained_bytes
      end

      if max_retention_ratio && diff&.retention_ratio && (diff.retention_ratio > max_retention_ratio)
        violations << "Retention ratio #{diff.retention_ratio} exceeds budget #{max_retention_ratio}"
      end

      violations << "RSS growth #{diff.rss_delta} exceeds budget #{max_rss_growth}" if max_rss_growth && diff&.rss_delta && diff.rss_delta > max_rss_growth

      if max_heap_live_growth && diff&.heap_live_delta && diff.heap_live_delta > max_heap_live_growth
        violations << "Heap live growth #{diff.heap_live_delta} exceeds budget #{max_heap_live_growth}"
      end

      rank = { low: 1, medium: 2, high: 3 }
      threshold = rank[severity_threshold] || 3
      report.findings.each do |f|
        next if (rank[f.severity] || 0) < threshold

        violations << "Finding #{f.code} severity #{f.severity} at/above threshold #{severity_threshold}"
      end

      { passed: violations.empty?, violations: violations, preset: preset_name }
    end

    def to_h
      {
        preset: preset_name,
        max_retained_objects: max_retained_objects,
        max_retained_bytes: max_retained_bytes,
        max_retention_ratio: max_retention_ratio,
        max_rss_growth: max_rss_growth,
        max_heap_live_growth: max_heap_live_growth,
        severity_threshold: severity_threshold
      }.compact
    end
  end
end
