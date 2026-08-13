# frozen_string_literal: true

require "json"
require "securerandom"
require "time"

module HeapScope
  # Stable snapshot abstraction. Configurable fidelity — not a full heap dump.
  class Snapshot
    SCHEMA_VERSION = HeapScope::SCHEMA_VERSION
    SLIM_CLASS_LIMIT = 40
    SLIM_ALLOC_LIMIT = 20

    attr_reader :id, :timestamp, :mode, :gc_stat, :rss_bytes, :class_stats,
                :allocation_sites, :metadata, :limitations, :sampled,
                :process, :duration_ms, :object_sample

    def initialize(id:, timestamp:, mode:, gc_stat:, rss_bytes:, class_stats:,
                   allocation_sites: {}, metadata: {}, limitations: [],
                   sampled: false, process: {}, duration_ms: 0, object_sample: [])
      @id = id
      @timestamp = timestamp
      @mode = mode
      @gc_stat = gc_stat || {}
      @rss_bytes = rss_bytes
      @class_stats = class_stats || {}
      @allocation_sites = allocation_sites || {}
      @metadata = metadata || {}
      @limitations = limitations || []
      @sampled = sampled
      @process = process || {}
      @duration_ms = duration_ms
      @object_sample = object_sample || []
    end

    def gc_generation
      gc_stat[:count]
    end

    def heap_live_slots
      gc_stat[:heap_live_slots]
    end

    def heap_free_slots
      gc_stat[:heap_free_slots]
    end

    def total_allocated_objects
      gc_stat[:total_allocated_objects]
    end

    def total_freed_objects
      gc_stat[:total_freed_objects]
    end

    def class_count(name)
      (class_stats[name.to_s] || {})[:count].to_i
    end

    def class_bytes(name)
      (class_stats[name.to_s] || {})[:shallow_bytes].to_i
    end

    def top_classes(limit = 20, by: :count)
      class_stats.values.sort_by { |s| -(s[by] || 0) }.first(limit)
    end

    def same_process?(other)
      process[:pid] == other.process[:pid]
    end

    def to_h(slim: false)
      stats = class_stats
      sites = allocation_sites
      sample = object_sample
      meta = metadata.dup
      limits = limitations.dup

      if slim
        top = top_classes(SLIM_CLASS_LIMIT)
        stats = top.to_h { |row| [row[:name], row] }
        sites =
          if allocation_sites.is_a?(Hash)
            allocation_sites.to_a.first(SLIM_ALLOC_LIMIT).to_h
          else
            Array(allocation_sites).first(SLIM_ALLOC_LIMIT)
          end
        sample = []
        meta[:slim] = true
        limits << "slim_json_truncated_classes" unless limits.include?("slim_json_truncated_classes")
      end

      {
        schema_version: SCHEMA_VERSION,
        heapscope_version: VERSION,
        id: id,
        timestamp: timestamp.iso8601(3),
        mode: mode.to_s,
        gc_stat: stringify_keys(gc_stat),
        rss_bytes: rss_bytes,
        class_stats: stats.transform_values { |v| stringify_keys(v) },
        allocation_sites: sites,
        metadata: meta,
        limitations: limits,
        sampled: sampled,
        process: process,
        duration_ms: duration_ms,
        object_sample: sample
      }
    end

    def to_json(*_args)
      JSON.pretty_generate(to_h)
    end

    def save(path, slim: false)
      File.write(path, JSON.pretty_generate(to_h(slim: slim)))
      path
    end

    def self.load(path)
      data = JSON.parse(File.read(path), symbolize_names: true)
      from_h(data)
    end

    def self.from_h(data)
      class_stats = (data[:class_stats] || {}).each_with_object({}) do |(name, stats), hash|
        hash[name.to_s] = {
          name: name.to_s,
          count: stats[:count].to_i,
          shallow_bytes: stats[:shallow_bytes].to_i,
          average_bytes: stats[:average_bytes].to_f
        }
      end

      new(
        id: data[:id] || SecureRandom.hex(8),
        timestamp: Time.parse(data[:timestamp].to_s),
        mode: (data[:mode] || "standard").to_sym,
        gc_stat: symbolize_keys(data[:gc_stat] || {}),
        rss_bytes: data[:rss_bytes],
        class_stats: class_stats,
        allocation_sites: data[:allocation_sites] || {},
        metadata: data[:metadata] || {},
        limitations: data[:limitations] || [],
        sampled: data[:sampled] || false,
        process: data[:process] || {},
        duration_ms: data[:duration_ms].to_f,
        object_sample: data[:object_sample] || []
      )
    end

    def self.stringify_keys(hash)
      hash.each_with_object({}) { |(k, v), h| h[k.to_s] = v }
    end

    def self.symbolize_keys(hash)
      hash.each_with_object({}) { |(k, v), h| h[k.to_sym] = v }
    end

    def stringify_keys(hash)
      self.class.stringify_keys(hash)
    end
  end
end
