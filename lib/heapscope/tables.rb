# frozen_string_literal: true

module HeapScope
  # ASCII / Markdown tables for diffs and class growth.
  module Tables
    module_function

    def class_growth(diff, limit: 15, format: :ascii)
      rows = diff.growing_classes(limit).map do |c|
        [
          c[:name].to_s,
          c[:before_count].to_s,
          c[:after_count].to_s,
          signed(c[:delta_count]),
          bytes(c[:delta_bytes])
        ]
      end
      headers = %w[CLASS BEFORE AFTER DELTA BYTES]
      format == :markdown ? markdown(headers, rows) : ascii(headers, rows)
    end

    def findings(report, format: :ascii)
      rows = report.findings.map { |f| [f.code, f.severity.to_s.upcase, f.title.to_s, f.subject.to_s] }
      headers = %w[CODE SEV TITLE SUBJECT]
      format == :markdown ? markdown(headers, rows) : ascii(headers, rows)
    end

    def ascii(headers, rows)
      widths = headers.each_index.map do |i|
        ([headers[i].length] + rows.map { |r| r[i].to_s.length }).max
      end
      sep = "+#{widths.map { |w| '-' * (w + 2) }.join('+')}+"
      line = lambda do |cols|
        cells = cols.each_with_index.map { |c, i| c.to_s.ljust(widths[i]) }.join(" | ")
        "| #{cells} |"
      end
      ([sep, line.call(headers), sep] + rows.map { |r| line.call(r) } + [sep]).join("\n")
    end

    def markdown(headers, rows)
      lines = []
      lines << "| #{headers.join(' | ')} |"
      lines << "| #{headers.map { '---' }.join(' | ')} |"
      rows.each { |r| lines << "| #{r.join(' | ')} |" }
      lines.join("\n")
    end

    def signed(n)
      n.positive? ? "+#{n}" : n.to_s
    end

    def bytes(n)
      return "n/a" if n.nil?

      format("%+.2fMB", n.to_f / (1024 * 1024))
    end
  end
end
