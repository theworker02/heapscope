# frozen_string_literal: true

require "json"
require "optparse"
require "fileutils"

require_relative "cli/color"
require_relative "cli/support"
require_relative "cli/help"
require_relative "cli/completion"
require_relative "cli/commands/capture"
require_relative "cli/commands/diffing"
require_relative "cli/commands/reporting"
require_relative "cli/commands/meta"

module HeapScope
  # Polished, expansive CLI for HeapScope diagnostics (local-only).
  class CLI
    include Support
    include Commands::Capture
    include Commands::Diffing
    include Commands::Reporting
    include Commands::Meta

    EXIT_OK = 0
    EXIT_REGRESSION = 1
    EXIT_INVALID = 2
    EXIT_CAPABILITY = 3

    COMMAND_MAP = {
      "snapshot" => :cmd_snapshot,
      "inspect" => :cmd_inspect,
      "diff" => :cmd_diff,
      "monitor" => :cmd_monitor,
      "watch" => :cmd_watch,
      "trends" => :cmd_trends,
      "report" => :cmd_report,
      "compare" => :cmd_compare,
      "baseline" => :cmd_baseline,
      "sessions" => :cmd_sessions,
      "history" => :cmd_history,
      "validate" => :cmd_validate,
      "suggest" => :cmd_suggest,
      "ignore-suggest" => :cmd_ignore_suggest,
      "pack" => :cmd_pack,
      "export" => :cmd_export,
      "probe" => :cmd_probe,
      "measure" => :cmd_measure,
      "retention" => :cmd_retention,
      "findings" => :cmd_findings,
      "scorecard" => :cmd_scorecard,
      "table" => :cmd_table,
      "explain" => :cmd_explain,
      "open" => :cmd_open,
      "html" => :cmd_html,
      "self-test" => :cmd_self_test,
      "env" => :cmd_env,
      "completion" => :cmd_completion,
      "man" => :cmd_man,
      "codes" => :cmd_codes,
      "doctor" => :cmd_doctor,
      "overhead" => :cmd_overhead,
      "config" => :cmd_config,
      "about" => :cmd_about,
      "capabilities" => :cmd_capabilities
    }.freeze

    def self.run(argv = ARGV)
      new.run(argv)
    end

    def initialize
      @json_mode = false
      @color_enabled = Color.enabled?
    end

    def run(argv)
      argv = argv.map(&:to_s)
      parse_globals!(argv)

      command = argv.shift
      case command
      when "version", "-v", "--version"
        puts "heapscope #{VERSION}"
        EXIT_OK
      when "help", "-h", "--help", nil
        topic = argv.shift
        if topic && Help::COMMANDS.key?(topic)
          puts Help.command_help(topic)
          EXIT_OK
        else
          print_help
          command.nil? ? EXIT_INVALID : EXIT_OK
        end
      else
        method = COMMAND_MAP[command]
        unless method
          say_err Color.err("Unknown command: #{command}", enabled: color?)
          print_help
          return EXIT_INVALID
        end
        send(method, argv)
      end
    rescue CapabilityError => e
      say_err "Capability unavailable: #{e.message}"
      EXIT_CAPABILITY
    rescue InvalidReportError, SnapshotError, ConfigurationError, ArgumentError => e
      say_err "Invalid input: #{e.message}"
      EXIT_INVALID
    rescue BudgetExceededError => e
      say_err e.message
      EXIT_REGRESSION
    end

    private

    def parse_globals!(argv)
      loop do
        break if argv.empty?

        case argv.first
        when "--verbose"
          argv.shift
          HeapScope.config.verbose = true
        when "--quiet"
          argv.shift
          HeapScope.config.quiet = true
        when "--json"
          argv.shift
          @json_mode = true
        when "--no-color"
          argv.shift
          @color_enabled = false
        when "--color"
          argv.shift
          @color_enabled = true
        when "--config"
          argv.shift
          path = argv.shift or raise ArgumentError, "--config requires PATH"
          HeapScope.load_config!(path)
        when /\A--config=(.+)\z/
          argv.shift
          HeapScope.load_config!(::Regexp.last_match(1))
        else
          break
        end
      end
    end

    def print_help
      puts Help.global_help
    end

    def help_exit(command)
      text = Help.command_help(command)
      if text
        puts text
        EXIT_OK
      else
        print_help
        EXIT_INVALID
      end
    end
  end
end
