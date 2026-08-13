# frozen_string_literal: true

require "securerandom"

module HeapScope
  # Collects heap snapshots at configurable fidelity with pause/object budgets.
  class Collector
    RUNTIME_NOISE = %w[
      Class Module Object BasicObject String Array Hash Integer Float Symbol
      Proc Method UnboundMethod Binding Encoding Range Regexp MatchData
      Thread Fiber Mutex Rational Complex NilClass TrueClass FalseClass
      RubyVM RubyVM::InstructionSequence IO File Dir Time Random
    ].freeze

    def initialize(runtime: Runtime.current, config: HeapScope.config)
      @runtime = runtime
      @config = config
    end

    def capture(mode: nil, metadata: {}, max_objects: nil, max_pause: nil, sample_rate: nil)
      mode = @config.effective_snapshot_mode(mode)
      max_objects ||= @config.max_objects
      sample_rate ||= @config.object_sample_rate
      max_pause_ms = normalize_pause(max_pause || @config.max_pause_ms)

      started = monotonic_ms
      limitations = []

      gc_stat = @runtime.gc_stat
      rss = safe_rss
      limitations << "rss_tracking_unavailable" if rss.nil? && !@runtime.rss_tracking?

      class_stats, allocation_sites, object_sample, truncated, more_limits =
        collect_objects(mode, max_objects, sample_rate, max_pause_ms, started)
      limitations.concat(more_limits)
      limitations << "analysis_truncated_pause_budget" if truncated && max_pause_ms

      duration = monotonic_ms - started

      Snapshot.new(
        id: SecureRandom.hex(8),
        timestamp: Time.now.utc,
        mode: mode,
        gc_stat: gc_stat,
        rss_bytes: rss,
        class_stats: class_stats,
        allocation_sites: allocation_sites,
        metadata: metadata,
        limitations: limitations.uniq,
        sampled: sample_rate < 1.0 || mode != :lightweight,
        process: @runtime.process_metadata,
        duration_ms: duration.round(2),
        object_sample: object_sample
      )
    rescue CapabilityError
      raise
    rescue StandardError => e
      raise SnapshotError, "Failed to capture snapshot: #{e.class}: #{e.message}"
    end

    private

    def collect_objects(mode, max_objects, sample_rate, max_pause_ms, started)
      return [{}, {}, [], false, ["each_object_unavailable"]] unless @runtime.each_object?

      counts = Hash.new { |h, k| h[k] = { name: k, count: 0, shallow_bytes: 0 } }
      allocation_sites = Hash.new { |h, k| h[k] = { site: k, count: 0, shallow_bytes: 0, classes: Hash.new(0) } }
      object_sample = []
      seen = 0
      truncated = false
      limitations = []

      estimate_memsize = mode != :lightweight && @runtime.memsize?
      track_alloc = mode != :lightweight && (@config.track_allocations || mode == :deep) && @runtime.allocation_tracing?
      sample_refs = mode == :deep

      limitations << "memsize_unavailable" unless @runtime.memsize?
      limitations << "allocation_tracing_not_enabled" if mode != :lightweight && !track_alloc

      @runtime.each_object do |object|
        break truncated = true if seen >= max_objects
        break truncated = true if max_pause_ms && (monotonic_ms - started) > max_pause_ms

        seen += 1
        next if sample_rate < 1.0 && rand > sample_rate

        name = safe_class_name(object)
        next if name.nil?

        counts[name][:count] += 1
        bytes = estimate_memsize ? (@runtime.memsize_of(object) || 0) : 0
        counts[name][:shallow_bytes] += bytes

        if track_alloc
          info = @runtime.allocation_info(object)
          if info && info[:file]
            site = "#{info[:file]}:#{info[:line]}"
            allocation_sites[site][:count] += 1
            allocation_sites[site][:shallow_bytes] += bytes
            allocation_sites[site][:classes][name] += 1
            allocation_sites[site][:method_id] ||= info[:method_id]&.to_s
          end
        end

        next unless sample_refs && object_sample.size < 50 && !noise?(name)

        object_sample << {
          local_id: object_sample.size,
          class: name,
          shallow_bytes: bytes,
          allocation: track_alloc ? @runtime.allocation_info(object) : nil
        }.compact
      end

      limitations << "object_budget_reached" if truncated && seen >= max_objects

      class_stats = counts.transform_values do |stats|
        avg = stats[:count].positive? ? (stats[:shallow_bytes].to_f / stats[:count]) : 0.0
        stats.merge(average_bytes: avg.round(2))
      end

      # Scale sampled counts when sample_rate < 1
      if sample_rate < 1.0 && sample_rate.positive?
        factor = 1.0 / sample_rate
        class_stats = class_stats.transform_values do |stats|
          stats.merge(
            count: (stats[:count] * factor).round,
            shallow_bytes: (stats[:shallow_bytes] * factor).round,
            sampled: true,
            sample_rate: sample_rate
          )
        end
        limitations << "object_counts_extrapolated_from_sample"
      end

      [class_stats, allocation_sites, object_sample, truncated, limitations]
    end

    def safe_class_name(object)
      object.class.name || "#<Anonymous:#{object.class.object_id}>"
    rescue StandardError
      nil
    end

    def noise?(name)
      RUNTIME_NOISE.include?(name) || name.start_with?("RubyVM")
    end

    def safe_rss
      @runtime.rss_bytes
    rescue StandardError
      nil
    end

    def normalize_pause(value)
      return nil if value.nil?
      return value if value.is_a?(Numeric)
      return value.to_f if value.respond_to?(:to_f)

      nil
    end

    def monotonic_ms
      Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond)
    end
  end
end
