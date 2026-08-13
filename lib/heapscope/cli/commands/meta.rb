# frozen_string_literal: true

module HeapScope
  class CLI
    module Commands
      # Doctor, about, env, codes, explain, completion, config, sessions, etc.
      module Meta
        private

        def cmd_capabilities(argv)
          options = {}
          OptionParser.new do |opts|
            opts.on("--json") { options[:json] = true }
            opts.on("-h", "--help") { options[:help] = true }
          end.parse!(argv)
          return help_exit("capabilities") if options[:help]

          caps = HeapScope.capabilities
          if json_mode? || options[:json]
            emit_json(caps.to_h)
          else
            puts caps
          end
          EXIT_OK
        end

        def cmd_doctor(argv)
          return help_exit("doctor") if command_wants_help?(argv)

          options = { fix_path: "heapscope.yml" }
          OptionParser.new do |opts|
            opts.on("--json") { options[:json] = true }
            opts.on("--fix", "Write a starter heapscope.yml (local only)") { options[:fix] = true }
            opts.on("--config-out PATH", "Output path for --fix (default heapscope.yml)") { |p| options[:fix_path] = p }
            opts.on("--force", "Overwrite existing config when using --fix") { options[:force] = true }
            opts.on("-h", "--help") { options[:help] = true }
          end.parse!(argv)
          return help_exit("doctor") if options[:help]

          if options[:fix]
            path = ConfigLoader.write_starter!(options[:fix_path], force: options[:force])
            say "Wrote starter config to #{path}"
            HeapScope.load_config!(path)
          end

          if json_mode? || options[:json]
            emit_json(HeapScope.doctor.merge(fragmentation: doctor_fragmentation, config_path: options[:fix] ? options[:fix_path] : nil))
            return EXIT_OK
          end

          puts Color.bold(Branding.compact_banner, enabled: color?)
          puts "HeapScope doctor"
          caps = HeapScope.capabilities
          puts "Ruby #{RUBY_VERSION} (#{RUBY_ENGINE}) on #{RUBY_PLATFORM}"
          puts
          puts caps
          puts
          puts "Config mode: #{HeapScope.config.mode}"
          puts "Noise patterns: #{HeapScope.config.ignore_patterns.size}"
          frag = doctor_fragmentation
          puts "Fragmentation indicator: #{frag[:status]} (#{frag[:note]})"
          puts "RSS tracking: #{caps.rss_tracking}"
          puts "Allocation tracing: #{caps.allocation_tracing}"
          puts "Reachable objects: #{caps.reachable_objects}"
          puts "Budget presets: #{Budget.presets.join(', ')}"
          puts
          Branding.funding_lines.each { |line| puts line }
          puts
          puts "Privacy: local-only, no telemetry, no value dumps by default."
          puts "Tip: heapscope doctor --fix   # write starter heapscope.yml"
          EXIT_OK
        end

        def doctor_fragmentation
          Fragmentation.assess(HeapScope.snapshot(mode: :lightweight))
        rescue StandardError => e
          { status: :error, note: e.message }
        end

        def cmd_overhead(argv)
          return help_exit("overhead") if command_wants_help?(argv)

          options = { mode: :lightweight, runs: 3 }
          OptionParser.new do |opts|
            opts.on("--mode MODE", %w[lightweight standard deep]) { |m| options[:mode] = m.to_sym }
            opts.on("--runs N", Integer) { |n| options[:runs] = n }
            opts.on("--json") { options[:json] = true }
            opts.on("-h", "--help") { options[:help] = true }
          end.parse!(argv)
          return help_exit("overhead") if options[:help]

          result = Overhead.measure_snapshot(mode: options[:mode], runs: options[:runs])
          if json_mode? || options[:json]
            emit_json(result)
          else
            puts "OVERHEAD mode=#{result[:mode]} avg=#{result[:avg_seconds]}s"
            result[:runs].each_with_index do |run, i|
              puts "  run #{i + 1}: #{run[:seconds].round(4)}s (#{run[:classes]} classes)"
            end
            puts result[:note]
          end
          EXIT_OK
        end

        def cmd_config(argv)
          return help_exit("config") if command_wants_help?(argv)

          path = argv.shift or raise ArgumentError, "config PATH required"
          HeapScope.load_config!(path)
          say "Loaded config from #{path}"
          say "mode=#{HeapScope.config.mode} track_allocations=#{HeapScope.config.track_allocations}"
          EXIT_OK
        end

        def cmd_codes(_argv)
          puts Catalog.to_text
          EXIT_OK
        end

        def cmd_explain(argv)
          return help_exit("explain") if command_wants_help?(argv)

          code = argv.shift or raise ArgumentError, "explain CODE required (e.g. HS001)"
          puts Catalog.explain(code)
          EXIT_OK
        end

        def cmd_sessions(_argv)
          sessions = Session.list
          if sessions.empty?
            say "No sessions in .heapscope/sessions"
            return EXIT_OK
          end
          sessions.each do |s|
            puts "#{s[:name]}  id=#{s[:id]}  reports=#{Array(s[:reports]).size}  created=#{s[:created_at]}"
          end
          EXIT_OK
        end

        def cmd_history(argv)
          return help_exit("history") if command_wants_help?(argv)

          options = { limit: 10 }
          OptionParser.new do |opts|
            opts.on("--limit N", Integer) { |n| options[:limit] = n }
            opts.on("-h", "--help") { options[:help] = true }
          end.parse!(argv)
          return help_exit("history") if options[:help]

          sessions = Session.list
          entries = sessions.flat_map { |s| Array(s[:reports]).map { |r| r.merge(session: s[:name]) } }
                            .sort_by { |e| e[:at].to_s }
                            .reverse
                            .first(options[:limit])
          if entries.empty?
            say "No history yet. Use HeapScope.session('name') in Ruby."
            return EXIT_OK
          end
          entries.each do |e|
            puts "#{e[:at]}  #{e[:session]}/#{e[:label]}  healthy=#{e[:healthy]}  #{e[:path]}"
          end
          EXIT_OK
        end

        def cmd_about(argv)
          options = {}
          OptionParser.new do |opts|
            opts.on("--json") { options[:json] = true }
            opts.on("-h", "--help") { options[:help] = true }
          end.parse!(argv)
          return help_exit("about") if options[:help]

          if json_mode? || options[:json]
            emit_json(Branding.to_h)
          else
            puts Branding.about_text
          end
          EXIT_OK
        end

        def cmd_man(_argv)
          puts Branding.banner
          puts
          puts Branding.about_text
          puts
          puts "Examples:"
          puts "  heapscope doctor"
          puts "  heapscope snapshot --mode standard -o before.json"
          puts "  heapscope diff before.json after.json --html out.html --fail-on-medium"
          puts "  heapscope probe --eval '1000.times { Object.new }'"
          puts "  heapscope explain HS001"
          puts "  heapscope self-test"
          puts "  heapscope pack report.json -o ./pack"
          puts
          puts "Exit codes: 0 ok · 1 regression · 2 invalid · 3 capability"
          puts "Privacy: local-only — no telemetry, no network from the gem."
          EXIT_OK
        end

        def cmd_env(argv)
          options = {}
          OptionParser.new do |opts|
            opts.on("--json") { options[:json] = true }
            opts.on("-h", "--help") { options[:help] = true }
          end.parse!(argv)
          return help_exit("env") if options[:help]

          keys = %w[
            RUBY_VERSION RUBYOPT RUBYLIB GEM_HOME GEM_PATH BUNDLE_GEMFILE
            HEAPSCOPE_CONFIG HEAPSCOPE_MODE HEAPSCOPE_QUIET
            NO_COLOR TERM FORCE_COLOR
          ]
          data = {
            ruby_version: RUBY_VERSION,
            ruby_engine: RUBY_ENGINE,
            ruby_platform: RUBY_PLATFORM,
            heapscope_version: VERSION,
            env: keys.to_h { |k| [k, ENV.fetch(k, nil)] }
          }
          if json_mode? || options[:json]
            emit_json(data)
          else
            puts Color.bold(Branding.compact_banner, enabled: color?)
            puts "RUBY_VERSION=#{RUBY_VERSION}  ENGINE=#{RUBY_ENGINE}  PLATFORM=#{RUBY_PLATFORM}"
            puts "HeapScope=#{VERSION}"
            puts
            data[:env].each do |k, v|
              puts format("%-18s %s", k, v.nil? ? "(unset)" : v)
            end
          end
          EXIT_OK
        end

        def cmd_completion(argv)
          return help_exit("completion") if command_wants_help?(argv)

          shell = argv.shift or raise ArgumentError, "completion requires bash|zsh|powershell"
          puts Completion.generate(shell)
          EXIT_OK
        end
      end
    end
  end
end
