# frozen_string_literal: true

module HeapScope
  class CLI
    # Shared helpers for option parsing, output, and severity exits.
    module Support
      SEVERITY_RANK = { low: 1, medium: 2, high: 3 }.freeze

      private

      def color?
        @color_enabled
      end

      def json_mode?
        @json_mode
      end

      def quiet?
        HeapScope.config.quiet
      end

      def say(msg = "")
        return if quiet?

        puts msg
      end

      def say_err(msg)
        warn msg
      end

      def emit_json(payload)
        puts JSON.pretty_generate(payload)
      end

      def colorize(text, code)
        Color.wrap(text, code, enabled: color?)
      end

      def load_report!(path)
        raise ArgumentError, "report path required" if path.nil? || path.empty?
        raise InvalidReportError, "File not found: #{path}" unless File.exist?(path)

        Report.load(path)
      end

      def load_json_path!(path)
        raise ArgumentError, "path required" if path.nil? || path.empty?
        raise InvalidReportError, "File not found: #{path}" unless File.exist?(path)

        JSON.parse(File.read(path), symbolize_names: true)
      end

      def parse_fail_on!(options, opts)
        opts.on("--fail-on-high", "Exit 1 if HIGH findings present") { options[:fail_on] = :high }
        opts.on("--fail-on-medium", "Exit 1 if MEDIUM or HIGH findings present") { options[:fail_on] = :medium }
        opts.on("--fail-on LEVEL", %w[low medium high], "Exit 1 if findings at/above LEVEL") do |level|
          options[:fail_on] = level.to_sym
        end
      end

      def exit_for_findings(report, fail_on: nil)
        return EXIT_OK unless fail_on

        threshold = SEVERITY_RANK[fail_on.to_sym]
        raise ArgumentError, "invalid fail-on level: #{fail_on}" unless threshold

        if report.findings.any? { |f| SEVERITY_RANK.fetch(f.severity.to_sym, 0) >= threshold }
          EXIT_REGRESSION
        else
          EXIT_OK
        end
      end

      def print_report_views(report, options)
        if json_mode? || options[:json]
          emit_json(report.to_h)
          return
        end

        if options[:scorecard_only]
          say report.scorecard(title: options[:title] || "HeapScope").to_text
          return
        end

        return if quiet?

        say report.scorecard(title: options[:title] || "HeapScope").to_text unless options[:no_scorecard]
        if options[:table] != false && report.diff
          say
          say report.table(format: options[:markdown] ? :markdown : :ascii)
        end
        say
        if options[:markdown]
          puts report.to_markdown
        else
          puts report.to_text
        end
      end

      def write_outputs(report, options)
        report.save(options[:output]) if options[:output]
        report.save_html(options[:html]) if options[:html]
        report.save_markdown(options[:markdown_out]) if options[:markdown_out]
      end

      def run_file_or_eval!(options)
        if options[:file]
          raise ArgumentError, "File not found: #{options[:file]}" unless File.exist?(options[:file])

          load(options[:file])
        elsif options[:eval]
          # Intentional: CLI probe/measure of user-provided snippet in local process only.
          eval(options[:eval], TOPLEVEL_BINDING, "(heapscope-eval)") # rubocop:disable Security/Eval
        else
          raise ArgumentError, "provide --file PATH or --eval 'ruby'"
        end
      end

      def command_wants_help?(argv)
        argv.any? { |a| a == "-h" || a == "--help" }
      end
    end
  end
end
