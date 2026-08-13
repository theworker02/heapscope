# frozen_string_literal: true

module HeapScope
  class CLI
    module Commands
      # Report rendering, pack/export, findings, scorecard, table, open/html.
      module Reporting
        private

        def cmd_report(argv)
          return help_exit("report") if command_wants_help?(argv)

          options = { format: "text", output: nil }
          OptionParser.new do |opts|
            opts.banner = "Usage: heapscope report REPORT.json [options]"
            opts.on("--format FMT", %w[text html json markdown md]) { |f| options[:format] = f }
            opts.on("-o", "--output PATH") { |p| options[:output] = p }
            opts.on("-h", "--help") { options[:help] = true }
          end.parse!(argv)
          return help_exit("report") if options[:help]

          path = argv.shift or raise ArgumentError, "report path required"
          report = load_report!(path)
          format = json_mode? ? "json" : options[:format]
          content =
            case format
            when "html" then Report::HTML.render(report)
            when "json" then report.to_json
            when "markdown", "md" then report.to_markdown
            else report.to_text
            end
          if options[:output]
            File.write(options[:output], content)
            say "Wrote #{options[:output]}"
          else
            puts content
          end
          EXIT_OK
        end

        def cmd_pack(argv)
          return help_exit("pack") if command_wants_help?(argv)

          options = { output: "heapscope-pack", label: "heapscope-report" }
          OptionParser.new do |opts|
            opts.banner = "Usage: heapscope pack REPORT.json [options]"
            opts.on("-o", "--output DIR", "Output directory") { |p| options[:output] = p }
            opts.on("--label NAME", "File basename") { |n| options[:label] = n }
            opts.on("--json") { options[:json] = true }
            opts.on("-h", "--help") { options[:help] = true }
          end.parse!(argv)
          return help_exit("pack") if options[:help]

          path = argv.shift or raise ArgumentError, "pack REPORT.json required"
          report = load_report!(path)
          result = Pack.export(report, options[:output], label: options[:label])
          if json_mode? || options[:json]
            emit_json(result)
          else
            say "Wrote local pack to #{result[:dir]}"
            say "  #{result[:json]}"
            say "  #{result[:html]}"
            say "  #{result[:markdown]}"
          end
          EXIT_OK
        end

        def cmd_export(argv)
          cmd_pack(argv)
        end

        def cmd_suggest(argv)
          return help_exit("suggest") if command_wants_help?(argv)

          options = {}
          OptionParser.new do |opts|
            opts.on("--json") { options[:json] = true }
            opts.on("--ignores-only") { options[:ignores_only] = true }
            opts.on("-h", "--help") { options[:help] = true }
          end.parse!(argv)
          return help_exit("suggest") if options[:help]

          path = argv.shift or raise ArgumentError, "suggest REPORT.json required"
          report = load_report!(path)
          if json_mode? || options[:json]
            payload = {
              next_steps: Suggest.next_steps(report),
              ignore_patterns: Suggest.ignore_patterns(report)
            }
            payload.delete(:next_steps) if options[:ignores_only]
            emit_json(payload)
          elsif options[:ignores_only]
            patterns = Suggest.ignore_patterns(report)
            if patterns.empty?
              say "No ignore suggestions."
            else
              patterns.each { |p| puts p }
            end
          else
            puts Suggest.report_text(report)
          end
          EXIT_OK
        end

        def cmd_ignore_suggest(argv)
          cmd_suggest(argv)
        end

        def cmd_findings(argv)
          return help_exit("findings") if command_wants_help?(argv)

          options = {}
          OptionParser.new do |opts|
            opts.on("--severity LEVEL", %w[low medium high]) { |s| options[:severity] = s.to_sym }
            opts.on("--code CODE") { |c| options[:code] = Catalog.normalize_code(c) }
            opts.on("--json") { options[:json] = true }
            opts.on("-h", "--help") { options[:help] = true }
          end.parse!(argv)
          return help_exit("findings") if options[:help]

          path = argv.shift or raise ArgumentError, "findings REPORT.json required"
          report = load_report!(path)
          list = Findings.rank_and_dedupe(report.findings)
          list = list.select { |f| f.severity.to_sym == options[:severity] } if options[:severity]
          list = list.select { |f| f.code == options[:code] } if options[:code]

          if json_mode? || options[:json]
            emit_json(findings: list.map(&:to_h), count: list.size)
          elsif list.empty?
            say "No findings matched."
          else
            puts Tables.findings(
              Report.new(findings: list, summary: report.summary, metadata: report.metadata),
              format: :ascii
            )
            list.each do |f|
              sev = Color.severity(f.severity, enabled: color?)
              say "#{f.code} [#{sev}] #{f.title}#{f.subject ? " (#{f.subject})" : ""}"
            end
          end
          EXIT_OK
        end

        def cmd_scorecard(argv)
          return help_exit("scorecard") if command_wants_help?(argv)

          options = { title: "HeapScope" }
          OptionParser.new do |opts|
            opts.on("--title NAME") { |t| options[:title] = t }
            opts.on("--json") { options[:json] = true }
            opts.on("-h", "--help") { options[:help] = true }
          end.parse!(argv)
          return help_exit("scorecard") if options[:help]

          path = argv.shift or raise ArgumentError, "scorecard REPORT.json required"
          report = load_report!(path)
          card = report.scorecard(title: options[:title])
          if json_mode? || options[:json]
            emit_json(card.to_h)
          else
            puts card.to_text
          end
          EXIT_OK
        end

        def cmd_table(argv)
          return help_exit("table") if command_wants_help?(argv)

          options = { top: 15 }
          OptionParser.new do |opts|
            opts.on("--markdown") { options[:markdown] = true }
            opts.on("--top N", Integer) { |n| options[:top] = n }
            opts.on("-h", "--help") { options[:help] = true }
          end.parse!(argv)
          return help_exit("table") if options[:help]

          path = argv.shift or raise ArgumentError, "table REPORT.json required"
          report = load_report!(path)
          raise ArgumentError, "report has no diff/table data" unless report.diff

          puts Tables.class_growth(
            report.diff,
            limit: options[:top],
            format: options[:markdown] ? :markdown : :ascii
          )
          EXIT_OK
        end

        def cmd_open(argv)
          return help_exit("open") if command_wants_help?(argv)

          options = {}
          OptionParser.new do |opts|
            opts.on("-o", "--output PATH") { |p| options[:output] = p }
            opts.on("-h", "--help") { options[:help] = true }
          end.parse!(argv)
          return help_exit("open") if options[:help]

          path = argv.shift or raise ArgumentError, "open REPORT.json required"
          report = load_report!(path)
          out = options[:output] || "#{path.sub(/\.json\z/i, "")}.html"
          out = "#{path}.html" if out == path
          report.save_html(out)
          if json_mode?
            emit_json(html: out)
          else
            puts out
          end
          EXIT_OK
        end

        def cmd_html(argv)
          cmd_open(argv)
        end

        def cmd_validate(argv)
          return help_exit("validate") if command_wants_help?(argv)

          path = argv.shift or raise ArgumentError, "validate REPORT.json required"
          data = load_json_path!(path)
          Schema.validate!(data)
          say "OK  schema_version=#{data[:schema_version]} heapscope=#{data[:heapscope_version]}"
          EXIT_OK
        end
      end
    end
  end
end
