# frozen_string_literal: true

module HeapScope
  # Multi-cycle retention analysis. Tracks populations that survive GC repeatedly.
  class RetentionSession
    Sample = Struct.new(:index, :snapshot, :after_gc, keyword_init: true)

    attr_reader :samples, :config, :force_gc

    def initialize(force_gc: true, mode: :lightweight, metadata: {})
      @force_gc = force_gc
      @mode = mode
      @metadata = metadata
      @samples = []
      @config = HeapScope.config
      @collector = Collector.new
    end

    def sample(label: nil)
      GC.start if force_gc
      snap = @collector.capture(
        mode: @mode,
        metadata: @metadata.merge(sample_index: @samples.size, label: label)
      )
      @samples << Sample.new(index: @samples.size, snapshot: snap, after_gc: force_gc)
      snap
    end

    def finish
      Report.from_retention_session(self)
    end

    def class_series
      names = samples.flat_map { |s| s.snapshot.class_stats.keys }.uniq
      names.each_with_object({}) do |name, hash|
        series = samples.map { |s| s.snapshot.class_count(name) }
        hash[name] = {
          name: name,
          series: series,
          trend: Growth.analyze(series),
          delta: series.last.to_i - series.first.to_i
        }
      end
    end

    def persistent_classes(min_cycles: 3, min_delta: 10)
      class_series.values.select do |entry|
        trend = entry[:trend]
        next false if entry[:series].size < min_cycles
        next false if entry[:delta] < min_delta
        next false if config.ignore_class?(entry[:name])

        %i[monotonic_growth linear_growth exponential_like].include?(trend[:pattern])
      end.sort_by { |e| -e[:delta] }
    end
  end

  # Allocation tracing helpers — opt-in only; never globally enable by surprise.
  class AllocationTracer
    def initialize(runtime: Runtime.current)
      @runtime = runtime
      @active = false
    end

    def available?
      @runtime.allocation_tracing?
    end

    def start!
      return false unless available?

      @runtime.start_allocation_tracing
      @active = true
      true
    end

    def stop!
      return unless @active

      @runtime.stop_allocation_tracing
      @active = false
    end

    def with_tracing
      started = start!
      yield
    ensure
      stop! if started
    end
  end
end
