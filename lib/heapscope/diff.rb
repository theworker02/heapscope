# frozen_string_literal: true

module HeapScope
  # Rich comparison between two snapshots.
  class Diff
    attr_reader :before, :after, :class_deltas, :rss_delta, :heap_live_delta,
                :allocated_delta, :freed_delta, :warnings, :allocation_deltas

    def initialize(before, after)
      @before = before
      @after = after
      @warnings = []
      @warnings << "snapshots_from_different_processes" unless before.same_process?(after)
      @class_deltas = compute_class_deltas
      @rss_delta = delta(after.rss_bytes, before.rss_bytes)
      @heap_live_delta = delta(after.heap_live_slots, before.heap_live_slots)
      @allocated_delta = delta(after.total_allocated_objects, before.total_allocated_objects)
      @freed_delta = delta(after.total_freed_objects, before.total_freed_objects)
      @allocation_deltas = compute_allocation_deltas
    end

    def surviving_estimate
      return nil if allocated_delta.nil? || freed_delta.nil?

      allocated_delta - freed_delta
    end

    def retention_ratio
      return nil if allocated_delta.nil? || allocated_delta <= 0

      surviving = surviving_estimate
      return nil if surviving.nil?

      surviving.to_f / allocated_delta
    end

    def top_growth(limit = 20)
      class_deltas.sort_by { |d| -d[:delta_count].abs }.first(limit)
    end

    def growing_classes(limit = 20)
      class_deltas.select { |d| d[:delta_count].positive? }
                  .sort_by { |d| -d[:delta_count] }
                  .first(limit)
    end

    def freed_classes(limit = 20)
      class_deltas.select { |d| d[:delta_count].negative? }
                  .sort_by { |d| d[:delta_count] }
                  .first(limit)
    end

    def new_classes
      class_deltas.select { |d| d[:before_count].zero? && d[:after_count].positive? }
    end

    def native_memory_mismatch?
      return false if rss_delta.nil? || heap_live_delta.nil?

      rss_delta > 10 * 1024 * 1024 && heap_live_delta < 50_000 &&
        (rss_delta > heap_bytes_estimate_delta * 3)
    end

    def heap_bytes_estimate_delta
      class_deltas.sum { |d| d[:delta_bytes] }
    end

    def to_h
      {
        before_id: before.id,
        after_id: after.id,
        rss_delta: rss_delta,
        heap_live_delta: heap_live_delta,
        allocated_delta: allocated_delta,
        freed_delta: freed_delta,
        surviving_estimate: surviving_estimate,
        retention_ratio: retention_ratio,
        class_deltas: class_deltas,
        allocation_deltas: allocation_deltas,
        warnings: warnings,
        native_memory_mismatch: native_memory_mismatch?
      }
    end

    def to_table(format: :ascii, limit: 15)
      Tables.class_growth(self, limit: limit, format: format)
    end

    private

    def compute_class_deltas
      names = (before.class_stats.keys + after.class_stats.keys).uniq
      names.map do |name|
        b = before.class_stats[name] || { count: 0, shallow_bytes: 0 }
        a = after.class_stats[name] || { count: 0, shallow_bytes: 0 }
        {
          name: name,
          before_count: b[:count].to_i,
          after_count: a[:count].to_i,
          delta_count: a[:count].to_i - b[:count].to_i,
          before_bytes: b[:shallow_bytes].to_i,
          after_bytes: a[:shallow_bytes].to_i,
          delta_bytes: a[:shallow_bytes].to_i - b[:shallow_bytes].to_i
        }
      end
    end

    def compute_allocation_deltas
      sites = (before.allocation_sites.keys + after.allocation_sites.keys).uniq
      sites.map do |site|
        b = before.allocation_sites[site] || { count: 0, shallow_bytes: 0 }
        a = after.allocation_sites[site] || { count: 0, shallow_bytes: 0 }
        {
          site: site,
          before_count: b[:count].to_i,
          after_count: a[:count].to_i,
          delta_count: a[:count].to_i - b[:count].to_i,
          delta_bytes: a[:shallow_bytes].to_i - b[:shallow_bytes].to_i,
          classes: a[:classes] || b[:classes] || {}
        }
      end.sort_by { |d| -d[:delta_count] }
    end

    def delta(after_v, before_v)
      return nil if after_v.nil? || before_v.nil?

      after_v - before_v
    end
  end
end
