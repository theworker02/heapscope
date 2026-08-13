# frozen_string_literal: true

module HeapScope
  # Pretty retention-path formatting and reproduction helpers.
  module Paths
    module_function

    def format_tree(path)
      return "Nearest observed retainer: unavailable" if path.nil? || Array(path.nodes).empty?

      lines = []
      lines << "LIKELY RETENTION PATH (confidence: #{path.confidence})"
      lines << "Note: #{path.note}" if path.note
      Array(path.nodes).each_with_index do |node, idx|
        via = node[:via] || node["via"] || node[:note] || "ref"
        prefix = idx.zero? ? "" : "#{"  " * idx}└── "
        lines << "#{prefix}#{via}"
      end
      lines.join("\n")
    end
  end

  module Reproduction
    module_function

    def command(metadata = {})
      mode = metadata[:mode] || HeapScope.config.mode
      script = metadata[:script] || "examples/import_leak.rb"
      "HEAPSCOPE_MODE=#{mode} bundle exec ruby #{script}"
    end

    def attach!(report, metadata = {})
      report.instance_variable_set(
        :@reproduction,
        {
          command: command(metadata),
          metadata: metadata,
          captured_at: Time.now.utc.iso8601
        }
      )
      report
    end
  end

  # Self-overhead profiler to avoid HeapScope dominating the workload.
  module Overhead
    module_function

    def measure_snapshot(mode: :lightweight, runs: 3)
      times = runs.times.map do
        t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        snap = HeapScope.snapshot(mode: mode, max_objects: 50_000)
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
        { seconds: elapsed, duration_ms: snap.duration_ms, classes: snap.class_stats.size }
      end
      {
        mode: mode,
        runs: times,
        avg_seconds: (times.sum { |t| t[:seconds] } / times.size).round(4),
        note: "HeapScope overhead for this mode on this machine."
      }
    end
  end
end
