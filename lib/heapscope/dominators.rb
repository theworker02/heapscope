# frozen_string_literal: true

module HeapScope
  # Approximate dominator-style analysis via bounded retained-size estimates.
  # Explicitly labeled approximate — not a JVM-style precise dominator tree.
  class Dominators
    Candidate = Struct.new(:class_name, :shallow, :approx_retained, :objects, :note, keyword_init: true)

    def initialize(runtime: Runtime.current, config: HeapScope.config)
      @runtime = runtime
      @config = config
      @graph = Graph.new(runtime: runtime, config: config)
    end

    def top_retainers(sample_objects, limit: 10)
      sample_objects.filter_map do |obj|
        next if obj.nil?

        est = @graph.estimate_retained_size(obj, max_objects: 2_000, max_depth: @config.max_graph_depth)
        Candidate.new(
          class_name: begin
            obj.class.name
          rescue StandardError
            "unknown"
          end,
          shallow: est[:shallow],
          approx_retained: est[:retained],
          objects: est[:objects],
          note: "Approximate retained size via bounded traversal — not a precise dominator."
        )
      rescue StandardError
        nil
      end.sort_by { |c| -(c.approx_retained || 0) }.first(limit)
    end

    def from_thread_locals(limit: 5)
      roots = []
      Thread.list.each do |thread|
        next unless thread.respond_to?(:keys)

        thread.each_key do |key|
          roots << thread[key]
        rescue StandardError
          next
        end
      end
      top_retainers(roots.compact.first(20), limit: limit)
    end
  end

  # Heuristic fragmentation / native mismatch indicators.
  module Fragmentation
    module_function

    def assess(snapshot)
      gc = snapshot.gc_stat
      rss = snapshot.rss_bytes
      live = gc[:heap_live_slots]
      free = gc[:heap_free_slots]
      pages = gc[:heap_allocated_pages]
      return { status: :unknown, note: "Insufficient GC/RSS data." } if rss.nil? || live.nil?

      heap_bytes_estimate = live.to_i * 40 # very rough average slot estimate
      ratio = heap_bytes_estimate.positive? ? rss.to_f / heap_bytes_estimate : nil
      free_ratio = (live.to_i + free.to_i).positive? ? free.to_f / (live + free) : nil

      status =
        if ratio && ratio > 4.0 && pages.to_i > 100
          :potential_fragmentation
        elsif ratio && ratio > 2.5
          :elevated_rss_vs_heap
        else
          :normal
        end

      {
        status: status,
        rss_bytes: rss,
        heap_bytes_estimate: heap_bytes_estimate,
        rss_to_heap_ratio: ratio&.round(2),
        free_slot_ratio: free_ratio&.round(3),
        heap_allocated_pages: pages,
        note: "Potential allocator/heap fragmentation indicator — not confirmed fragmentation."
      }
    end
  end
end
