# frozen_string_literal: true

module HeapScope
  class Report
    module Markdown
      module_function

      def render(report)
        lines = []
        lines << "# HeapScope Report"
        lines << ""
        lines << "- **Version:** #{report.heapscope_version}"
        lines << "- **Ruby:** #{report.runtime_info[:ruby]} (#{report.runtime_info[:engine]})"
        lines << "- **Result:** #{report.summary[:healthy] ? "HEALTHY" : "ATTENTION"}"
        lines << ""
        if report.before && report.after
          lines << "## Memory"
          lines << ""
          lines << "| Metric | Before | After | Delta |"
          lines << "|--------|--------|-------|-------|"
          lines << "| RSS | #{mb(report.before.rss_bytes)} | #{mb(report.after.rss_bytes)} | #{mb(report.diff&.rss_delta)} |"
          lines << "| Live slots | #{report.before.heap_live_slots} | #{report.after.heap_live_slots} | #{report.diff&.heap_live_delta} |"
          lines << ""
        end
        if report.diff
          lines << "## Top class growth"
          lines << ""
          lines << "| Class | Before | After | Delta | Bytes Δ |"
          lines << "|-------|--------|-------|-------|---------|"
          report.diff.growing_classes(15).each do |c|
            lines << "| `#{c[:name]}` | #{c[:before_count]} | #{c[:after_count]} | #{c[:delta_count]} | #{mb(c[:delta_bytes])} |"
          end
          lines << ""
        end
        unless report.findings.empty?
          lines << "## Findings"
          lines << ""
          report.findings.each do |f|
            lines << "### #{f.code} — #{f.title} (`#{f.severity}`)"
            f.facts.each { |fact| lines << "- Fact: #{fact}" }
            f.derived.each { |d| lines << "- Derived: #{d}" }
            lines << "- Hypothesis: #{f.hypothesis}" if f.hypothesis
            lines << "- Suspected cause: #{f.suspected_cause}" if f.suspected_cause
            lines << ""
          end
        end
        if report.reproduction
          lines << "## Reproduction"
          lines << ""
          lines << "```bash"
          lines << report.reproduction[:command].to_s
          lines << "```"
          lines << ""
        end
        steps = Suggest.next_steps(report)
        unless steps.empty?
          lines << "## Next steps"
          lines << ""
          steps.each_with_index do |step, i|
            tag = step[:code] || "hint"
            lines << "#{i + 1}. **[#{tag}]** #{step[:action]}"
          end
          lines << ""
        end
        lines << "_Privacy: object values are not serialized by default._"
        lines << ""
        lines << "_#{Branding.report_footer}_"
        lines.join("\n")
      end

      def mb(n)
        return "n/a" if n.nil?

        format("%.2f MB", n.to_f / (1024 * 1024))
      end
    end
  end
end
