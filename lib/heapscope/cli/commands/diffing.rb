# frozen_string_literal: true

module HeapScope
  class CLI
    module Commands
      # Diff / compare / baseline / trends.
      module Diffing
        private

        def cmd_diff(argv)
          return help_exit("diff") if command_wants_help?(argv)

          options = { output: nil, html: nil, top: 15 }
          OptionParser.new do |opts|
            opts.banner = "Usage: heapscope diff BEFORE.json AFTER.json [options]"
            opts.on("-o", "--output PATH", "Write report JSON") { |p| options[:output] = p }
            opts.on("--html PATH", "Write HTML report") { |p| options[:html] = p }
            opts.on("--markdown", "Markdown report body") { options[:markdown] = true }
            opts.on("--markdown-out PATH", "Write Markdown file") { |p| options[:markdown_out] = p }
            opts.on("--top N", Integer) { |n| options[:top] = n }
            opts.on("--scorecard-only") { options[:scorecard_only] = true }
            opts.on("--json") { options[:json] = true }
            parse_fail_on!(options, opts)
            # Back-compat alias already covered by --fail-on-high via parse_fail_on!
            opts.on("-h", "--help") { options[:help] = true }
          end.parse!(argv)
          return help_exit("diff") if options[:help]

          before_path, after_path = argv.shift(2)
          raise ArgumentError, "diff requires BEFORE.json AFTER.json" unless before_path && after_path

          report = HeapScope.compare(before_path, after_path)
          if options[:top] && report.diff
            options[:table_text] = Tables.class_growth(report.diff, limit: options[:top],
                                                                    format: options[:markdown] ? :markdown : :ascii)
          end

          if json_mode? || options[:json]
            emit_json(report.to_h)
          elsif options[:scorecard_only]
            say report.scorecard.to_text
          else
            unless quiet?
              say report.scorecard.to_text
              say
              say(options[:table_text] || report.table)
              say
              puts(options[:markdown] ? report.to_markdown : report.to_text)
            end
          end

          write_outputs(report, options)
          exit_for_findings(report, fail_on: options[:fail_on])
        end

        def cmd_baseline(argv)
          return help_exit("baseline") if command_wants_help?(argv)

          sub = argv.shift
          case sub
          when "create"
            options = { output: "baseline.json" }
            OptionParser.new do |opts|
              opts.on("-o", "--output PATH") { |p| options[:output] = p }
              opts.on("-h", "--help") { options[:help] = true }
            end.parse!(argv)
            return help_exit("baseline") if options[:help]

            input = argv.shift or raise ArgumentError, "baseline create requires REPORT.json"
            Baseline.create(input, options[:output])
            say "Created baseline #{options[:output]}"
            EXIT_OK
          when nil, "-h", "--help"
            help_exit("baseline")
          else
            say_err "Usage: heapscope baseline create REPORT.json -o baseline.json"
            EXIT_INVALID
          end
        end

        def cmd_compare(argv)
          return help_exit("compare") if command_wants_help?(argv)

          options = { threshold: 0.5 }
          OptionParser.new do |opts|
            opts.banner = "Usage: heapscope compare BASELINE.json CURRENT.json"
            opts.on("--threshold F", Float) { |f| options[:threshold] = f }
            opts.on("--json") { options[:json] = true }
            opts.on("-h", "--help") { options[:help] = true }
          end.parse!(argv)
          return help_exit("compare") if options[:help]

          baseline, current = argv.shift(2)
          raise ArgumentError, "compare requires BASELINE.json CURRENT.json" unless baseline && current

          result = Baseline.compare(baseline, current, threshold: options[:threshold])
          if json_mode? || options[:json]
            emit_json(
              result.merge(
                findings: result[:findings].map { |f| f.respond_to?(:to_h) ? f.to_h : f }
              )
            )
          else
            puts Color.bold("MEMORY COMPARISON", enabled: color?)
            puts "Retained objects: baseline=#{result[:baseline_retained_objects]} current=#{result[:current_retained_objects]}"
            puts "Change: #{(result[:object_change_ratio] * 100).round(1)}%"
            puts "Retained bytes: baseline=#{result[:baseline_retained_bytes]} current=#{result[:current_retained_bytes]}"
            label = result[:result]
            colored =
              if result[:regression]
                Color.err(label, enabled: color?)
              else
                Color.ok(label, enabled: color?)
              end
            puts "Result: #{colored}"
            result[:findings].each { |f| puts "#{f.code}: #{f.title}" }
          end
          result[:regression] ? EXIT_REGRESSION : EXIT_OK
        end

        def cmd_trends(argv)
          return help_exit("trends") if command_wants_help?(argv)

          options = {}
          OptionParser.new do |opts|
            opts.on("--json") { options[:json] = true }
            opts.on("-h", "--help") { options[:help] = true }
          end.parse!(argv)
          return help_exit("trends") if options[:help]

          path = argv.shift or raise ArgumentError, "trends REPORT.json required"
          report = load_report!(path)
          timeline = report.metadata[:timeline] || report.metadata["timeline"]
          if timeline.nil? || timeline.empty?
            say_err "No timeline in report. Run: heapscope monitor ..."
            return EXIT_INVALID
          end
          if json_mode? || options[:json]
            emit_json(timeline: timeline)
          else
            puts "TIME                 RSS          LIVE         TOP"
            timeline.each do |row|
              puts format(
                "%-20s %-12s %-12s %s",
                row[:time] || row["time"],
                row[:rss_bytes] || row["rss_bytes"],
                row[:live_slots] || row["live_slots"],
                row[:top_class] || row["top_class"]
              )
            end
          end
          EXIT_OK
        end
      end
    end
  end
end
