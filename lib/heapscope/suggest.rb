# frozen_string_literal: true

module HeapScope
  # Ignore-pattern suggestions and prioritized next-step recommendations.
  # Never auto-applies configuration — returns guidance only.
  module Suggest
    NEXT_STEP_BY_CODE = {
      "HS001" => "Run HeapScope.retention_test (multi-cycle + force_gc) on the top growing class.",
      "HS002" => "Force GC between snapshots and re-measure retention ratio after idle recovery.",
      "HS003" => "Inventory Thread.current keys after the request/job and clear request-scoped locals.",
      "HS004" => "Bound or expire the growing collection; confirm whether it is an intentional cache.",
      "HS005" => "Audit callback/subscriber registries for unbounded appends across requests.",
      "HS006" => "Check Proc/lambda captures for long-lived owners (controllers, jobs, threads).",
      "HS007" => "Compare pre-GC vs post-GC snapshots; investigate sticky populations that survive GC.",
      "HS008" => "Diff against the saved baseline and gate CI with Budget.preset(:ci_strict).",
      "HS009" => "Treat as churn unless RSS/live slots also climb; optimize hot allocation sites if GC-bound.",
      "HS010" => "Do not assume a Ruby object leak — check native extensions and allocator fragmentation."
    }.freeze

    module_function

    def ignore_patterns(report)
      names = report.diff&.growing_classes(50)&.map { |c| c[:name] } || []
      patterns = Noise.suggestion_patterns
      hints = names.select { |n| patterns.any? { |re| n.match?(re) } }
      stable = Array(report.suspects).select { |s| s[:severity] == :low }.map { |s| s[:name] }
      (hints + stable).uniq
                      .reject { |n| Noise.noisy?(n) }
                      .map { |n| "^#{Regexp.escape(n)}" }
    end

    def next_steps(report, limit: 8)
      steps = []
      ranked = Findings.rank_and_dedupe(report.findings)
      ranked.first(limit).each do |finding|
        base = NEXT_STEP_BY_CODE[finding.code] || "Review finding #{finding.code} evidence and suggestions."
        subject = finding.subject ? " (#{finding.subject})" : ""
        steps << {
          priority: Findings.priority_score(finding),
          code: finding.code,
          severity: finding.severity,
          action: "#{base}#{subject}",
          suggestions: finding.suggestions
        }
      end

      if report.summary[:healthy] == false && steps.empty?
        steps << {
          priority: 40,
          code: nil,
          severity: :medium,
          action: "Review top suspects and class growth table; run heapscope suggest on this report.",
          suggestions: []
        }
      end

      ignores = ignore_patterns(report)
      if ignores.any?
        steps << {
          priority: 5,
          code: nil,
          severity: :low,
          action: "Review #{ignores.size} suggested ignore_pattern(s) before applying (never auto-applied).",
          suggestions: ignores.first(5)
        }
      end

      steps.sort_by { |s| -s[:priority].to_i }.first(limit)
    end

    def report_text(report)
      patterns = ignore_patterns(report)
      steps = next_steps(report)
      lines = []

      lines << "Next steps (prioritized):"
      if steps.empty?
        lines << "  (none — report looks quiet)"
      else
        steps.each_with_index do |step, i|
          tag = step[:code] ? "[#{step[:code]}]" : "[hint]"
          lines << "  #{i + 1}. #{tag} #{step[:action]}"
        end
      end

      lines << ""
      if patterns.empty?
        lines << "No ignore suggestions."
      else
        lines << "Suggested ignore_patterns (review before applying):"
        patterns.each { |p| lines << "  - #{p}" }
        lines << ""
        lines << "HeapScope.configure { |c| c.ignore_patterns << /.../ }"
      end

      lines.join("\n")
    end
  end
end
