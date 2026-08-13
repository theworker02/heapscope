# frozen_string_literal: true

require "fileutils"
require "json"

module HeapScope
  # Export a self-contained local report bundle (JSON + HTML + Markdown + notes).
  # Never uploads; writes only to the destination directory.
  module Pack
    module_function

    def export(report, dir, label: "heapscope-report")
      FileUtils.mkdir_p(dir)
      base = File.join(dir, label)
      json_path = "#{base}.json"
      html_path = "#{base}.html"
      md_path = "#{base}.md"
      readme_path = File.join(dir, "README.txt")

      report.save(json_path)
      File.write(html_path, Report::HTML.render(report))
      File.write(md_path, report.to_markdown)
      File.write(readme_path, readme_body(report, label: label))

      {
        dir: dir,
        json: json_path,
        html: html_path,
        markdown: md_path,
        readme: readme_path
      }
    end

    def readme_body(report, label:)
      lines = []
      lines << Branding.compact_banner
      lines << ""
      lines << "Local report bundle: #{label}"
      lines << "Generated: #{Time.now.utc.iso8601}"
      lines << "Result: #{report.summary[:healthy] ? 'HEALTHY' : 'ATTENTION'}"
      lines << "Findings: #{report.findings.size}"
      lines << ""
      lines << "Files:"
      lines << "  #{label}.json       — machine-readable report"
      lines << "  #{label}.html       — shareable HTML (local file)"
      lines << "  #{label}.md         — Markdown summary"
      lines << ""
      lines << "This bundle was generated offline. It was not uploaded anywhere."
      lines << ""
      Branding.funding_lines.each { |l| lines << l }
      lines.join("\n")
    end
    private_class_method :readme_body
  end
end
