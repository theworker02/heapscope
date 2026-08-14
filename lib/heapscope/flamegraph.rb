# frozen_string_literal: true

module HeapScope
  # Turns snapshot allocation sites into folded stacks or Speedscope JSON.
  #
  # Folded output is compatible with inferno / flamegraph.pl. Speedscope JSON
  # can be dropped onto https://www.speedscope.app (local file, no upload required
  # by HeapScope itself).
  class Flamegraph
    FORMATS = %i[folded speedscope].freeze

    Frame = Struct.new(:site, :method_id, :klass, :allocations, :bytes, keyword_init: true)

    attr_reader :frames, :snapshot_id, :unit

    def initialize(frames:, snapshot_id: nil, unit: :count)
      @frames = frames
      @snapshot_id = snapshot_id
      @unit = unit
    end

    def self.from_snapshot(snapshot, unit: :count)
      raise ArgumentError, "unit must be :count or :bytes" unless %i[count bytes].include?(unit.to_sym)

      snapshot = Snapshot.load(snapshot) if snapshot.is_a?(String)
      frames = []
      snapshot.allocation_sites.each do |site_key, stats|
        stats = symbolize(stats)
        site = stats[:site] || site_key.to_s
        method_id = stats[:method_id]
        classes = stats[:classes] || {}
        if classes.empty?
          frames << Frame.new(
            site: site,
            method_id: method_id,
            klass: nil,
            allocations: stats[:count].to_i,
            bytes: stats[:shallow_bytes].to_i
          )
        else
          classes.each do |klass, class_count|
            share = stats[:count].to_i.positive? ? (class_count.to_f / stats[:count]) : 0.0
            frames << Frame.new(
              site: site,
              method_id: method_id,
              klass: klass.to_s,
              allocations: class_count.to_i,
              bytes: (stats[:shallow_bytes].to_i * share).round
            )
          end
        end
      end
      new(frames: frames.sort_by { |frame| [-value_for(frame, unit), frame.site.to_s] },
          snapshot_id: snapshot.id, unit: unit.to_sym)
    end

    def empty?
      frames.empty? || total.zero?
    end

    def total
      frames.sum { |frame| value_for(frame, unit) }
    end

    def to_folded
      frames.filter_map do |frame|
        weight = value_for(frame, unit)
        next if weight <= 0

        "#{stack_for(frame)} #{weight}"
      end.join("\n")
    end

    def to_speedscope
      names = []
      name_index = {}
      samples = []
      weights = []

      frames.each do |frame|
        weight = value_for(frame, unit)
        next if weight <= 0

        stack = []
        stack_for(frame).split(";").each do |name|
          unless name_index.key?(name)
            name_index[name] = names.length
            names << name
          end
          stack << name_index[name]
        end
        samples << stack
        weights << weight
      end

      {
        "$schema" => "https://www.speedscope.app/file-format-schema.json",
        shared: { frames: names.map { |name| { name: name } } },
        profiles: [
          {
            type: "sampled",
            name: "HeapScope allocations (#{unit})",
            unit: unit == :bytes ? "bytes" : "none",
            startValue: 0,
            endValue: weights.sum,
            samples: samples,
            weights: weights
          }
        ],
        exporter: "heapscope #{VERSION}",
        name: snapshot_id && "heapscope-#{snapshot_id}"
      }.compact
    end

    def render(format: :folded)
      format = format.to_sym
      raise ArgumentError, "unknown flamegraph format #{format}" unless FORMATS.include?(format)

      format == :speedscope ? JSON.pretty_generate(to_speedscope) : to_folded
    end

    def to_h
      {
        snapshot_id: snapshot_id,
        unit: unit,
        total: total,
        frames: frames.map do |frame|
          {
            site: frame.site,
            method_id: frame.method_id,
            class: frame.klass,
            count: frame.allocations,
            bytes: frame.bytes,
            stack: stack_for(frame)
          }
        end
      }
    end

    class << self
      def value_for(frame, unit)
        unit.to_sym == :bytes ? frame.bytes.to_i : frame.allocations.to_i
      end

      def symbolize(value)
        return value unless value.is_a?(Hash)

        value.each_with_object({}) do |(key, nested), acc|
          acc[key.to_sym] = nested.is_a?(Hash) ? symbolize(nested) : nested
        end
      end
    end

    private_class_method :value_for, :symbolize

    private

    def value_for(frame, unit)
      self.class.send(:value_for, frame, unit)
    end

    def stack_for(frame)
      parts = [frame.site.to_s]
      parts << frame.method_id if frame.method_id && !frame.method_id.to_s.empty?
      parts << frame.klass if frame.klass && !frame.klass.to_s.empty?
      parts.join(";")
    end
  end
end
