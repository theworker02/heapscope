# frozen_string_literal: true

module HeapScope
  class Report
    module Text
      module_function

      def render(report)
        lines = []
        lines << "╔══════════════════════════════════════════╗"
        lines << "║              HEAPSCOPE REPORT            ║"
        lines << "╚══════════════════════════════════════════╝"
        lines << "Ruby: #{report.runtime_info[:ruby]} (#{report.runtime_info[:engine]})"
        lines << "HeapScope: #{report.heapscope_version}"
        lines << ""

        if report.summary[:healthy]
          lines << "Result: HEALTHY"
          lines << "Peak object growth occurred during workload may have been reclaimed."
          lines << "Persistent class growth: none significant." if report.findings.none? { |f| f.code == "HS001" }
        else
          lines << "Result: ATTENTION"
        end
        lines << ""

        if report.before && report.after
          lines << "RSS"
          lines << "  Before: #{mb(report.before.rss_bytes)}"
          lines << "  After:  #{mb(report.after.rss_bytes)}"
          lines << "  Delta:  #{mb_delta(report.diff&.rss_delta)}"
          lines << ""
          lines << "Ruby Heap (live slots)"
          lines << "  Before: #{fmt(report.before.heap_live_slots)}"
          lines << "  After:  #{fmt(report.after.heap_live_slots)}"
          lines << "  Delta:  #{signed(report.diff&.heap_live_delta)}"
          lines << ""
        end

        if report.diff
          ratio = report.diff.retention_ratio
          lines << "Allocated Δ: #{fmt(report.diff.allocated_delta)}"
          lines << "Freed Δ:     #{fmt(report.diff.freed_delta)}"
          lines << "Surviving ≈: #{fmt(report.diff.surviving_estimate)}"
          lines << "Retention:   #{ratio ? format('%.2f%%', ratio * 100) : 'n/a'}"
          lines << ""
          lines << "TOP CLASS GROWTH"
          lines << "CLASS                            BEFORE      AFTER      DELTA      BYTES Δ"
          report.diff.growing_classes(15).each do |c|
            lines << format("%-28s %10s %10s %10s %12s",
                            truncate(c[:name], 28),
                            fmt(c[:before_count]),
                            fmt(c[:after_count]),
                            signed(c[:delta_count]),
                            mb_delta(c[:delta_bytes]))
          end
          lines << ""
        end

        if report.retention
          lines << "RETENTION SESSION"
          lines << "  Samples: #{report.retention[:samples]}"
          lines << "  Force GC: #{report.retention[:force_gc]}"
          Array(report.retention[:persistent]).first(10).each do |entry|
            lines << "  #{entry[:name]}: #{entry[:series].inspect} (#{entry[:trend][:pattern]}, slope #{entry[:trend][:slope]})"
          end
          lines << ""
        end

        unless report.suspects.empty?
          lines << "TOP SUSPECTS"
          report.suspects.first(8).each_with_index do |s, i|
            lines << "  #{i + 1}. #{s[:name]}  #{s[:severity].to_s.upcase}"
            lines << "     +#{s[:delta_count]} retained  class=#{s[:classification]}"
          end
          lines << ""
        end

        unless report.findings.empty?
          lines << "FINDINGS"
          report.findings.each do |f|
            lines << "  #{f.code} — #{f.title} [#{f.severity.to_s.upcase}]"
            f.facts.each { |fact| lines << "    Fact: #{fact}" }
            f.derived.each { |d| lines << "    Derived: #{d}" }
            lines << "    Hypothesis: #{f.hypothesis}" if f.hypothesis
            lines << "    Suspected cause: #{f.suspected_cause}" if f.suspected_cause
            f.suggestions.each { |s| lines << "    → #{s}" }
            lines << ""
          end
        end

        unless report.limitations.empty?
          lines << "LIMITATIONS"
          report.limitations.each { |l| lines << "  - #{l}" }
          lines << ""
        end

        if report.budget_result
          lines << "BUDGET: #{report.budget_result[:passed] ? 'PASS' : 'FAIL'}"
          Array(report.budget_result[:violations]).each { |v| lines << "  - #{v}" }
          lines << ""
        end

        if report.fragmentation
          lines << "FRAGMENTATION INDICATOR"
          lines << "  Status: #{report.fragmentation[:status]}"
          lines << "  RSS/heap ratio ≈ #{report.fragmentation[:rss_to_heap_ratio]}"
          lines << "  #{report.fragmentation[:note]}"
          lines << ""
        end

        if report.aging && !report.aging.empty?
          lines << "OBJECT AGING (coarse)"
          report.aging.first(8).each do |row|
            lines << "  #{row[:class]}  bucket=#{row[:bucket]}  survived=#{row[:survived_ratio]}  series=#{row[:series].inspect}"
          end
          lines << "  Note: coarse multi-cycle survival buckets — not exact ages."
          lines << ""
        end

        if report.retention_paths && !report.retention_paths.empty?
          lines << "RETENTION PATHS / RETAINERS"
          report.retention_paths.each do |block|
            lines << "  #{block[:summary]}"
            Array(block[:retainers]).each do |r|
              lines << "    - #{r[:class]} approx_retained=#{r[:approx_retained]} (#{r[:note]})"
            end
          end
          lines << ""
        end

        if report.dominators && !report.dominators.empty?
          lines << "APPROXIMATE TOP RETAINERS"
          report.dominators.first(5).each do |d|
            name = d.respond_to?(:class_name) ? d.class_name : d[:class_name]
            retained = d.respond_to?(:approx_retained) ? d.approx_retained : d[:approx_retained]
            lines << "  #{name}: approx retained #{retained}"
          end
          lines << ""
        end

        if report.reproduction
          lines << "REPRODUCTION"
          lines << "  #{report.reproduction[:command]}"
          lines << ""
        end

        steps = Suggest.next_steps(report)
        unless steps.empty?
          lines << "NEXT STEPS"
          steps.each_with_index do |step, i|
            tag = step[:code] ? "[#{step[:code]}]" : "[hint]"
            lines << "  #{i + 1}. #{tag} #{step[:action]}"
          end
          lines << ""
        end

        alerts = report.metadata[:alerts] || report.metadata["alerts"]
        if alerts && !alerts.empty?
          lines << "MONITOR ALERTS"
          Array(alerts).each do |a|
            kind = a[:kind] || a["kind"]
            msg = a[:message] || a["message"]
            lines << "  - #{kind}: #{msg}"
          end
          lines << ""
        end

        lines << "Privacy: object values are not serialized by default."
        Branding.funding_lines.each { |l| lines << l }
        lines << Branding.report_footer
        lines.join("\n")
      end

      def mb(bytes)
        return "n/a" if bytes.nil?

        format("%.2f MB", bytes.to_f / (1024 * 1024))
      end

      def mb_delta(bytes)
        return "n/a" if bytes.nil?

        sign = bytes.positive? ? "+" : ""
        format("%s%.2f MB", sign, bytes.to_f / (1024 * 1024))
      end

      def fmt(n)
        return "n/a" if n.nil?

        n.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
      end

      def signed(n)
        return "n/a" if n.nil?

        n.positive? ? "+#{fmt(n)}" : fmt(n)
      end

      def truncate(str, len)
        str.length > len ? "#{str[0, len - 1]}…" : str
      end
    end
  end
end
