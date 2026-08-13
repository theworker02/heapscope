# frozen_string_literal: true

module HeapScope
  # Approximate object aging across forced GC cycles.
  # Does not invent ages the runtime cannot support — labels are coarse.
  class Aging
    BUCKETS = %i[young middle_aged long_lived unknown].freeze

    Sample = Struct.new(:cycle_index, :class_counts, :generation_hint, keyword_init: true)

    def initialize(runtime: Runtime.current)
      @runtime = runtime
      @samples = []
    end

    def sample!(cycle:)
      counts = Hash.new(0)
      if @runtime.each_object?
        @runtime.each_object do |obj|
          name = begin
            obj.class.name
          rescue StandardError
            nil
          end
          next unless name

          counts[name] += 1
        end
      end
      push_counts(cycle: cycle, counts: counts, generation_hint: (GC.stat[:count] if GC.respond_to?(:stat)))
    end

    def push_counts(cycle:, counts:, generation_hint: nil)
      @samples << Sample.new(cycle_index: cycle, class_counts: counts, generation_hint: generation_hint)
      self
    end

    def classify(class_name)
      series = @samples.map { |s| s.class_counts[class_name].to_i }
      return { bucket: :unknown, series: series } if series.size < 2

      first = series.first
      last = series.last
      survived_ratio = first.positive? ? last.to_f / first : 0.0
      bucket =
        if survived_ratio < 0.2
          :young
        elsif survived_ratio < 0.7
          :middle_aged
        else
          :long_lived
        end

      {
        class: class_name,
        bucket: bucket,
        series: series,
        survived_ratio: survived_ratio.round(4),
        note: "Coarse age bucket from multi-cycle survival — not exact object age."
      }
    end

    def report(top: 20)
      names = @samples.flat_map { |s| s.class_counts.keys }.uniq
      names.map { |n| classify(n) }
           .select { |r| r[:series].last.to_i > 10 }
           .sort_by { |r| -r[:survived_ratio] }
           .first(top)
    end
  end

  # Tracks GC stats around workloads for recovery correlation.
  class GCTracker
    def initialize
      @points = []
    end

    def mark(label)
      @points << {
        label: label,
        at: Time.now.utc,
        gc_stat: Runtime.current.gc_stat.dup,
        rss_bytes: begin
          Runtime.current.rss_bytes
        rescue StandardError
          nil
        end
      }
      self
    end

    def correlation
      return {} if @points.size < 2

      first = @points.first
      last = @points.last
      {
        points: @points,
        major_gc_delta: delta(last[:gc_stat][:major_gc_count], first[:gc_stat][:major_gc_count]),
        minor_gc_delta: delta(last[:gc_stat][:minor_gc_count], first[:gc_stat][:minor_gc_count]),
        live_slots_delta: delta(last[:gc_stat][:heap_live_slots], first[:gc_stat][:heap_live_slots]),
        rss_delta: delta(last[:rss_bytes], first[:rss_bytes])
      }
    end

    private

    def delta(a, b)
      return nil if a.nil? || b.nil?

      a - b
    end
  end
end
