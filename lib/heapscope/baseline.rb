# frozen_string_literal: true

require "json"

module HeapScope
  module Baseline
    module_function

    def create(report_or_path, output_path)
      report = report_or_path.is_a?(Report) ? report_or_path : Report.load(report_or_path)
      payload = {
        schema_version: SCHEMA_VERSION,
        kind: "baseline",
        created_at: Time.now.utc.iso8601,
        heapscope_version: VERSION,
        summary: report.summary,
        classes: top_classes(report),
        rss_bytes: report.after&.rss_bytes || report.before&.rss_bytes,
        heap_live_slots: report.after&.heap_live_slots || report.before&.heap_live_slots,
        retained_objects_estimate: report.diff&.surviving_estimate,
        retained_bytes_estimate: report.diff&.heap_bytes_estimate_delta
      }
      File.write(output_path, JSON.pretty_generate(payload))
      output_path
    end

    def compare(baseline_path, current_path_or_report, threshold: 0.5)
      baseline = JSON.parse(File.read(baseline_path), symbolize_names: true)
      current = current_path_or_report.is_a?(Report) ? current_path_or_report : Report.load(current_path_or_report)

      base_retained = baseline[:retained_objects_estimate].to_i
      curr_retained = current.diff&.surviving_estimate.to_i
      change = if base_retained.zero?
                 curr_retained.positive? ? 1.0 : 0.0
               else
                 (curr_retained - base_retained).to_f / base_retained
               end

      base_bytes = baseline[:retained_bytes_estimate].to_i
      curr_bytes = current.diff&.heap_bytes_estimate_delta.to_i
      bytes_change = base_bytes.zero? ? 0.0 : (curr_bytes - base_bytes).to_f / base_bytes

      regression = change > threshold || bytes_change > threshold
      findings = []
      if regression
        findings << Finding.new(
          code: "HS008",
          severity: :high,
          facts: [
            "Observed fact: retained objects baseline=#{base_retained} current=#{curr_retained}.",
            "Observed fact: retained bytes baseline=#{base_bytes} current=#{curr_bytes}."
          ],
          derived: [
            "Derived: object change #{(change * 100).round(1)}%, bytes change #{(bytes_change * 100).round(1)}%."
          ],
          hypothesis: "Current run exceeds baseline retention beyond threshold #{threshold}."
        )
      end

      {
        regression: regression,
        baseline_retained_objects: base_retained,
        current_retained_objects: curr_retained,
        object_change_ratio: change,
        baseline_retained_bytes: base_bytes,
        current_retained_bytes: curr_bytes,
        bytes_change_ratio: bytes_change,
        findings: findings,
        result: regression ? "REGRESSION" : "OK"
      }
    end

    def top_classes(report)
      (report.classes || []).first(50)
    end
  end
end
