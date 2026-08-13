# frozen_string_literal: true

require "json"

module HeapScope
  # Persists monitor samples for historical trend reports.
  class TrendStore
    def initialize(path)
      @path = path
    end

    def append(sample_hash)
      rows = load
      rows << sample_hash
      File.write(@path, JSON.pretty_generate(rows))
      rows.size
    end

    def load
      return [] unless File.exist?(@path)

      JSON.parse(File.read(@path), symbolize_names: true)
    rescue StandardError
      []
    end

    def summary
      rows = load
      return { samples: 0 } if rows.empty?

      rss = rows.map { |r| r[:rss_bytes].to_i }
      live = rows.map { |r| r[:live_slots].to_i }
      {
        samples: rows.size,
        rss: { first: rss.first, last: rss.last, delta: rss.last - rss.first, max: rss.max },
        live_slots: { first: live.first, last: live.last, delta: live.last - live.first, max: live.max },
        top_classes: rows.map { |r| r[:top_class] }.compact.tally.sort_by { |_, v| -v }.first(5)
      }
    end
  end
end
