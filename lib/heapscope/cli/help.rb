# frozen_string_literal: true

module HeapScope
  class CLI
    # Help text and per-command usage.
    module Help
      COMMANDS = {
        "snapshot" => "Capture a heap snapshot to JSON",
        "inspect" => "Inspect current process (embedded) or a saved capture",
        "diff" => "Diff two snapshots (scorecard + table + report)",
        "monitor" => "Sample the current process for a duration",
        "watch" => "Monitor with anomaly alerts enabled (alias)",
        "trends" => "Summarize a monitor/report timeline",
        "report" => "Render a text/HTML/markdown/JSON report",
        "compare" => "Compare a baseline to a current report",
        "baseline" => "Create a baseline from a report",
        "sessions" => "List saved .heapscope sessions",
        "history" => "Show recent session reports",
        "validate" => "Validate a report JSON schema",
        "suggest" => "Suggest ignore_patterns from a report",
        "ignore-suggest" => "Alias of suggest",
        "pack" => "Export a local JSON+HTML+Markdown report bundle",
        "export" => "Alias of pack",
        "probe" => "Measure a Ruby file/snippet and print a scorecard",
        "measure" => "CLI wrapper around HeapScope.measure",
        "retention" => "CLI wrapper around HeapScope.retention_test",
        "flamegraph" => "Export allocation sites as folded stacks or Speedscope JSON",
        "findings" => "List/filter findings from a report",
        "scorecard" => "Print scorecard only from a report",
        "table" => "Print growth table from a report",
        "explain" => "Print diagnostic encyclopedia entry for a code",
        "open" => "Write HTML for a report and print the path",
        "html" => "Alias of open",
        "self-test" => "Run a built-in retention demo and show findings",
        "env" => "Print HeapScope-relevant environment variables",
        "completion" => "Generate bash/zsh/powershell completion scripts",
        "man" => "Extended about + examples",
        "codes" => "List diagnostic codes (HS001–HS010)",
        "doctor" => "Diagnose runtime capabilities & config",
        "overhead" => "Measure HeapScope snapshot overhead",
        "config" => "Load a YAML/Ruby config file",
        "about" => "Branding, docs, and funding links",
        "capabilities" => "Show runtime capabilities",
        "version" => "Print version",
        "help" => "Show help (or help <command>)"
      }.freeze

      module_function

      def global_help
        lines = []
        lines << Branding.compact_banner
        lines << ""
        lines << "Usage:"
        lines << "  heapscope [global options] <command> [options]"
        lines << ""
        lines << "Global options:"
        lines << "  --verbose          Verbose HeapScope logging"
        lines << "  --quiet            Suppress non-essential output"
        lines << "  --config PATH      Load YAML/Ruby config before command"
        lines << "  --json             Prefer machine-readable JSON on key commands"
        lines << "  --no-color         Disable ANSI colors"
        lines << "  --color            Force ANSI colors"
        lines << "  -h, --help         Show help"
        lines << "  -v, --version      Print version"
        lines << ""
        lines << "Commands:"
        COMMANDS.each do |name, desc|
          lines << format("  %-14s %s", name, desc)
        end
        lines << ""
        lines << "Exit codes:"
        lines << "  0 success"
        lines << "  1 regression / finding above threshold"
        lines << "  2 invalid input/configuration"
        lines << "  3 runtime capability unavailable"
        lines << ""
        lines << "Privacy: no network, no telemetry, no object value serialization by default."
        lines << "Gem:     #{Branding::RUBYGEMS_URL}"
        lines << "Sponsor: #{Branding::THANKS_DEV_URL}"
        lines << "Docs:    #{Branding::PAGES_URL}"
        lines << ""
        lines << "Try: heapscope help <command>   or   heapscope <command> --help"
        lines.join("\n")
      end

      def command_help(name)
        key = name.to_s
        desc = COMMANDS[key]
        return nil unless desc

        body = USAGE.fetch(key, "Usage: heapscope #{key} [options]\n\n#{desc}")
        "#{Branding.compact_banner}\n\n#{body}\n"
      end

      USAGE = {
        "snapshot" => <<~U,
          Usage: heapscope snapshot [options]
            --mode MODE              lightweight|standard|deep
            -o, --output PATH        Output JSON path
            --slim                   Slim JSON (top classes / truncated sites)
            --force-gc               Force GC before capture
            --track-allocations      Enable allocation tracing for this capture
        U
        "inspect" => <<~U,
          Usage: heapscope inspect [capture.json] [options]
            --mode MODE              Snapshot mode when inspecting live process
            --top N                  Limit class rows in derived views
            --html PATH              Also write HTML
            --markdown               Print Markdown instead of text
            --json                   Print JSON
            --fail-on-high           Exit 1 on HIGH findings
        U
        "diff" => <<~U,
          Usage: heapscope diff BEFORE.json AFTER.json [options]
            -o, --output PATH        Write report JSON
            --html PATH              Write HTML report
            --markdown               Print Markdown report body
            --top N                  Limit growth table rows
            --scorecard-only         Print scorecard only
            --fail-on-high           Exit 1 if HIGH findings
            --fail-on-medium         Exit 1 if MEDIUM or HIGH
            --json                   Print report JSON
        U
        "monitor" => <<~U,
          Usage: heapscope monitor [options]
            --interval SEC           Sample interval (min 2)
            --duration SEC           Total duration
            --mode MODE              lightweight|standard
            --alert                  Emit RSS / live-slot spike alerts
            --rss-alert-bytes N      RSS delta threshold (default 25MB)
            --live-alert-slots N     Live-slot delta threshold
            -o, --output PATH        Report JSON path
            --html PATH              Also write HTML
            --fail-on-high           Exit 1 on HIGH findings
        U
        "watch" => <<~U,
          Usage: heapscope watch [options]
            Same as `monitor`, with --alert enabled by default.
        U
        "probe" => <<~U,
          Usage: heapscope probe --file script.rb [options]
                 heapscope probe --eval 'ruby code' [options]
            --file PATH              Load Ruby file inside measured block
            --eval CODE              Eval Ruby snippet inside measured block
            --title NAME             Scorecard title
            --mode MODE              Snapshot mode
            --force-gc / --no-force-gc
            -o, --output PATH        Save report JSON
            --html PATH              Save HTML
            --json                   Print JSON report
        U
        "measure" => <<~U,
          Usage: heapscope measure --file script.rb [options]
            --file PATH / --eval CODE
            --mode MODE --force-gc --recovery-wait SEC
            --track-allocations
            -o, --output PATH --html PATH --json
            --fail-on-high / --fail-on-medium
        U
        "retention" => <<~U,
          Usage: heapscope retention --file script.rb [options]
            --cycles N               Retention cycles (default 5)
            --file PATH / --eval CODE
            --mode MODE --force-gc / --no-force-gc
            -o, --output PATH --html PATH --json
            --fail-on-high / --fail-on-medium
        U
        "flamegraph" => <<~U,
          Usage: heapscope flamegraph SNAPSHOT.json [options]
            --format FMT             folded (default) or speedscope
            --unit UNIT              count (default) or bytes
            -o, --output PATH        Write the flamegraph instead of stdout
            --json                   Print frame table JSON
        U
        "findings" => <<~U,
          Usage: heapscope findings REPORT.json [options]
            --severity LEVEL       Filter: low|medium|high
            --code HS001             Filter by diagnostic code
            --json                   Machine-readable output
        U
        "scorecard" => "Usage: heapscope scorecard REPORT.json [--json] [--title NAME]\n",
        "table" => "Usage: heapscope table REPORT.json [--markdown] [--top N]\n",
        "explain" => "Usage: heapscope explain CODE\n\nExample: heapscope explain HS001\n",
        "open" => "Usage: heapscope open REPORT.json [-o out.html]\n",
        "html" => "Usage: heapscope html REPORT.json [-o out.html]\n",
        "self-test" => "Usage: heapscope self-test [--json] [-o report.json]\n\nRuns a built-in intentional retention demo (local only).\n",
        "env" => "Usage: heapscope env [--json]\n",
        "completion" => "Usage: heapscope completion bash|zsh|powershell\n",
        "man" => "Usage: heapscope man\n\nExtended branding, privacy notes, and examples.\n",
        "pack" => <<~U,
          Usage: heapscope pack REPORT.json [options]
            -o, --output DIR         Output directory
            --label NAME             File basename
        U
        "export" => "Alias of pack. See: heapscope help pack\n",
        "suggest" => <<~U,
          Usage: heapscope suggest REPORT.json [options]
            --json                   next_steps + ignore_patterns
            --ignores-only           Print ignore patterns only
        U
        "ignore-suggest" => "Alias of suggest. See: heapscope help suggest\n",
        "report" => <<~U,
          Usage: heapscope report REPORT.json [options]
            --format FMT             text|html|json|markdown|md
            -o, --output PATH
        U
        "baseline" => "Usage: heapscope baseline create REPORT.json -o baseline.json\n",
        "compare" => <<~U,
          Usage: heapscope compare BASELINE.json CURRENT.json [options]
            --threshold F            Relative growth threshold (default 0.5)
            --json                   Machine-readable result
        U
        "codes" => "Usage: heapscope codes\n",
        "doctor" => <<~U,
          Usage: heapscope doctor [options]
            --json                   Machine-readable doctor payload
            --fix                   Write starter heapscope.yml
            --config-out PATH        Path for --fix (default ./heapscope.yml)
            --force                  Overwrite existing config with --fix
        U
        "overhead" => "Usage: heapscope overhead [--mode MODE] [--runs N] [--json]\n",
        "config" => "Usage: heapscope config PATH\n",
        "about" => "Usage: heapscope about [--json]\n",
        "capabilities" => "Usage: heapscope capabilities [--json]\n",
        "sessions" => "Usage: heapscope sessions\n",
        "history" => "Usage: heapscope history [--limit N]\n",
        "validate" => "Usage: heapscope validate REPORT.json\n",
        "trends" => "Usage: heapscope trends REPORT.json\n",
        "version" => "Usage: heapscope version\n",
        "help" => "Usage: heapscope help [command]\n"
      }.freeze
    end
  end
end
