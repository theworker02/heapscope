# frozen_string_literal: true

module HeapScope
  class CLI
    # Capture / live-process commands.
    module Commands
      module Capture
        private

        def cmd_snapshot(argv)
          return help_exit("snapshot") if command_wants_help?(argv)

          options = { mode: :standard, output: "heapscope-snapshot.json", slim: false }
          OptionParser.new do |opts|
            opts.banner = "Usage: heapscope snapshot [options]"
            opts.on("--mode MODE", %w[lightweight standard deep], "Snapshot mode") { |m| options[:mode] = m.to_sym }
            opts.on("-o", "--output PATH", "Output JSON path") { |p| options[:output] = p }
            opts.on("--slim", "Write slim JSON (top classes only)") { options[:slim] = true }
            opts.on("--force-gc", "Force GC before capture") { options[:force_gc] = true }
            opts.on("--track-allocations", "Enable allocation tracing for this capture") { options[:track_allocations] = true }
            opts.on("--verbose", "Verbose logging") { HeapScope.config.verbose = true }
            opts.on("-h", "--help", "Show help") { options[:help] = true }
          end.parse!(argv)
          return help_exit("snapshot") if options[:help]

          HeapScope.config.track_allocations = true if options[:track_allocations]
          GC.start if options[:force_gc]
          snap = HeapScope.snapshot(mode: options[:mode])
          snap.save(options[:output], slim: options[:slim])
          if json_mode?
            emit_json(snap.to_h(slim: options[:slim]).merge(saved_to: options[:output]))
          else
            say "Wrote snapshot #{snap.id} (mode=#{snap.mode}#{options[:slim] ? ', slim' : ''}) to #{options[:output]}"
            say "Limitations: #{snap.limitations.join(', ')}" unless snap.limitations.empty?
          end
          EXIT_OK
        end

        def cmd_inspect(argv)
          return help_exit("inspect") if command_wants_help?(argv)

          options = { mode: :standard, top: 30 }
          OptionParser.new do |opts|
            opts.banner = "Usage: heapscope inspect [capture.json] [options]"
            opts.on("--mode MODE", %w[lightweight standard deep]) { |m| options[:mode] = m.to_sym }
            opts.on("--html PATH", "Also write HTML") { |p| options[:html] = p }
            opts.on("--top N", Integer, "Top class rows") { |n| options[:top] = n }
            opts.on("--markdown", "Markdown output") { options[:markdown] = true }
            opts.on("--json", "JSON output") { options[:json] = true }
            parse_fail_on!(options, opts)
            opts.on("-h", "--help") { options[:help] = true }
          end.parse!(argv)
          return help_exit("inspect") if options[:help]

          path = argv.shift
          report =
            if path
              raise InvalidReportError, "File not found: #{path}" unless File.exist?(path)

              data = JSON.parse(File.read(path), symbolize_names: true)
              if data[:schema_version] && data[:findings]
                Report.from_h(data)
              else
                snap = Snapshot.from_h(data)
                Report.new(
                  summary: { healthy: true },
                  after: snap,
                  classes: snap.top_classes(options[:top]),
                  metadata: { kind: "inspect_capture" },
                  limitations: snap.limitations,
                  runtime_info: { ruby: RUBY_VERSION, engine: RUBY_ENGINE }
                )
              end
            else
              say_err "Note: remote PID attachment is not supported; inspecting current process." unless quiet?
              before = HeapScope.snapshot(mode: :lightweight)
              GC.start
              after = HeapScope.snapshot(mode: options[:mode])
              HeapScope.compare(before, after, metadata: { kind: "inspect" })
            end

          print_report_views(report, options)
          write_outputs(report, options)
          exit_for_findings(report, fail_on: options[:fail_on])
        end

        def cmd_monitor(argv)
          return help_exit("monitor") if command_wants_help?(argv)

          options = {
            interval: 10,
            duration: 60,
            mode: :lightweight,
            output: "heapscope-monitor.json",
            alert: false,
            rss_alert_bytes: 25 * 1024 * 1024,
            live_alert_slots: 80_000
          }
          OptionParser.new do |opts|
            opts.banner = "Usage: heapscope monitor [options]"
            opts.on("--interval SEC", Integer) { |n| options[:interval] = n }
            opts.on("--duration SEC", Integer) { |n| options[:duration] = n }
            opts.on("--mode MODE", %w[lightweight standard]) { |m| options[:mode] = m.to_sym }
            opts.on("--alert", "Emit anomaly alerts on RSS/live-slot spikes") { options[:alert] = true }
            opts.on("--rss-alert-bytes N", Integer) { |n| options[:rss_alert_bytes] = n }
            opts.on("--live-alert-slots N", Integer) { |n| options[:live_alert_slots] = n }
            opts.on("-o", "--output PATH") { |p| options[:output] = p }
            opts.on("--html PATH") { |p| options[:html] = p }
            parse_fail_on!(options, opts)
            opts.on("-h", "--help") { options[:help] = true }
          end.parse!(argv)
          return help_exit("monitor") if options[:help]

          raise ArgumentError, "interval too aggressive (min 2s)" if options[:interval] < 2

          monitor = Monitor.start(
            interval: options[:interval],
            mode: options[:mode],
            alert: options[:alert],
            rss_alert_bytes: options[:rss_alert_bytes],
            live_alert_slots: options[:live_alert_slots]
          )
          say "Monitoring for #{options[:duration]}s every #{options[:interval]}s#{options[:alert] ? ' (alerts on)' : ''}..."
          sleep options[:duration]
          report = monitor.stop
          report.save(options[:output])
          report.save_html(options[:html]) if options[:html]
          if json_mode?
            emit_json(report.to_h.merge(saved_to: options[:output]))
          else
            puts report.to_text unless quiet?
            say "Wrote #{options[:output]}"
            say "Alerts: #{monitor.alerts.size}" if options[:alert]
          end
          exit_for_findings(report, fail_on: options[:fail_on])
        end

        def cmd_watch(argv)
          argv = ["--alert", *argv] unless argv.include?("--alert") || argv.include?("--help") || argv.include?("-h")
          cmd_monitor(argv)
        end

        def cmd_probe(argv)
          return help_exit("probe") if command_wants_help?(argv)

          options = { title: "probe", mode: :lightweight, force_gc: true }
          OptionParser.new do |opts|
            opts.banner = "Usage: heapscope probe --file script.rb|--eval CODE [options]"
            opts.on("--file PATH") { |p| options[:file] = p }
            opts.on("--eval CODE") { |c| options[:eval] = c }
            opts.on("--title NAME") { |t| options[:title] = t }
            opts.on("--mode MODE", %w[lightweight standard deep]) { |m| options[:mode] = m.to_sym }
            opts.on("--force-gc") { options[:force_gc] = true }
            opts.on("--no-force-gc") { options[:force_gc] = false }
            opts.on("-o", "--output PATH") { |p| options[:output] = p }
            opts.on("--html PATH") { |p| options[:html] = p }
            opts.on("--json") { options[:json] = true }
            parse_fail_on!(options, opts)
            opts.on("-h", "--help") { options[:help] = true }
          end.parse!(argv)
          return help_exit("probe") if options[:help]

          result = HeapScope.probe(
            title: options[:title],
            force_gc: options[:force_gc],
            mode: options[:mode],
            print: !(json_mode? || options[:json] || quiet?)
          ) { run_file_or_eval!(options) }

          report = result.report
          write_outputs(report, options)
          emit_json(report.scorecard(title: options[:title]).to_h.merge(report: report.to_h)) if json_mode? || options[:json]
          exit_for_findings(report, fail_on: options[:fail_on])
        end

        def cmd_measure(argv)
          return help_exit("measure") if command_wants_help?(argv)

          options = { mode: :standard, force_gc: HeapScope.config.force_gc_default }
          OptionParser.new do |opts|
            opts.banner = "Usage: heapscope measure --file script.rb|--eval CODE [options]"
            opts.on("--file PATH") { |p| options[:file] = p }
            opts.on("--eval CODE") { |c| options[:eval] = c }
            opts.on("--mode MODE", %w[lightweight standard deep]) { |m| options[:mode] = m.to_sym }
            opts.on("--force-gc") { options[:force_gc] = true }
            opts.on("--no-force-gc") { options[:force_gc] = false }
            opts.on("--recovery-wait SEC", Float) { |n| options[:recovery_wait] = n }
            opts.on("--track-allocations") { options[:track_allocations] = true }
            opts.on("-o", "--output PATH") { |p| options[:output] = p }
            opts.on("--html PATH") { |p| options[:html] = p }
            opts.on("--markdown") { options[:markdown] = true }
            opts.on("--json") { options[:json] = true }
            parse_fail_on!(options, opts)
            opts.on("-h", "--help") { options[:help] = true }
          end.parse!(argv)
          return help_exit("measure") if options[:help]

          report = HeapScope.measure(
            force_gc: options[:force_gc],
            mode: options[:mode],
            recovery_wait: options[:recovery_wait],
            track_allocations: options[:track_allocations] || HeapScope.config.track_allocations,
            metadata: { kind: "cli_measure" }
          ) { run_file_or_eval!(options) }

          print_report_views(report, options)
          write_outputs(report, options)
          exit_for_findings(report, fail_on: options[:fail_on])
        end

        def cmd_retention(argv)
          return help_exit("retention") if command_wants_help?(argv)

          options = { cycles: 5, mode: :lightweight, force_gc: true }
          OptionParser.new do |opts|
            opts.banner = "Usage: heapscope retention --file script.rb|--eval CODE [options]"
            opts.on("--cycles N", Integer) { |n| options[:cycles] = n }
            opts.on("--file PATH") { |p| options[:file] = p }
            opts.on("--eval CODE") { |c| options[:eval] = c }
            opts.on("--mode MODE", %w[lightweight standard deep]) { |m| options[:mode] = m.to_sym }
            opts.on("--force-gc") { options[:force_gc] = true }
            opts.on("--no-force-gc") { options[:force_gc] = false }
            opts.on("-o", "--output PATH") { |p| options[:output] = p }
            opts.on("--html PATH") { |p| options[:html] = p }
            opts.on("--markdown") { options[:markdown] = true }
            opts.on("--json") { options[:json] = true }
            parse_fail_on!(options, opts)
            opts.on("-h", "--help") { options[:help] = true }
          end.parse!(argv)
          return help_exit("retention") if options[:help]

          report = HeapScope.retention_test(
            cycles: options[:cycles],
            force_gc: options[:force_gc],
            mode: options[:mode],
            metadata: { kind: "cli_retention" }
          ) { run_file_or_eval!(options) }

          print_report_views(report, options)
          write_outputs(report, options)
          exit_for_findings(report, fail_on: options[:fail_on])
        end

        def cmd_self_test(argv)
          return help_exit("self-test") if command_wants_help?(argv)

          options = {}
          OptionParser.new do |opts|
            opts.on("-o", "--output PATH") { |p| options[:output] = p }
            opts.on("--html PATH") { |p| options[:html] = p }
            opts.on("--json") { options[:json] = true }
            opts.on("-h", "--help") { options[:help] = true }
          end.parse!(argv)
          return help_exit("self-test") if options[:help]

          leak = []
          result = HeapScope.probe(
            title: "self-test retention fixture",
            force_gc: true,
            mode: :lightweight,
            print: !(json_mode? || options[:json] || quiet?)
          ) do
            800.times { leak << ("heapscope-self-test-" * 4) }
          end

          report = result.report
          write_outputs(report, options)
          if json_mode? || options[:json]
            emit_json(
              scorecard: report.scorecard(title: "self-test").to_h,
              findings: report.findings.map(&:to_h),
              note: "Intentional retention demo; leak array held #{leak.size} strings."
            )
          else
            say
            say Color.accent("Self-test complete (intentional retention; local-only).", enabled: color?)
            say "Findings: #{report.findings.size}  Suspects: #{report.suspects.size}"
            report.findings.each do |f|
              sev = Color.severity(f.severity, enabled: color?)
              say "  #{f.code} [#{sev}] #{f.title}"
            end
            say "Privacy: no network, no telemetry."
          end
          EXIT_OK
        end
      end
    end
  end
end
