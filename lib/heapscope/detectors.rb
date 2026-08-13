# frozen_string_literal: true

module HeapScope
  # Pattern detectors for cache-vs-leak, unbounded collections, and thread-locals.
  # Findings remain evidence-based: facts, derived behavior, hypothesis, suspected cause.
  module Detectors
    module_function

    def analyze_thread_locals(runtime: Runtime.current)
      findings = []
      inventory = Graph.new(runtime: runtime).thread_local_inventory
      inventory.each do |thread|
        thread[:keys].each do |key, meta|
          bytes = meta[:shallow_bytes].to_i
          next if bytes < 64_000 && !suspicious_key?(key)

          findings << Finding.new(
            code: "HS003",
            severity: bytes >= 1_000_000 ? :high : :medium,
            subject: "#{thread[:name]}#{key}",
            facts: [
              "Observed fact: thread #{thread[:name]} holds key #{key} of class #{meta[:class]}."
            ],
            derived: [
              "Derived: shallow size estimate #{format_bytes(bytes)}."
            ],
            hypothesis: "Thread-local state may retain request/job context across reuse of this thread.",
            suspected_cause: "Thread-local #{key}",
            suggestions: [
              "Clear the key in an ensure block after each request/job",
              "Avoid storing full request graphs on long-lived Puma/Sidekiq threads",
              "Confirm whether this cache is intentional and bounded"
            ],
            evidence: [{ thread: thread[:name], key: key, meta: meta }]
          )
        end
      end
      { inventory: inventory, findings: findings }
    end

    def classify_collection_growth(name:, sizes:, owner: nil)
      return { kind: :insufficient_data } if sizes.size < 3

      trend = Growth.analyze(sizes)
      max_size = sizes.max
      min_size = sizes.min
      last = sizes.last(3)
      plateau = last.max - last.min <= [last.max * 0.05, 2].max
      shrinking = sizes.each_cons(2).any? { |a, b| b < a }

      kind =
        if plateau && max_size > 0 && sizes.first < max_size
          :likely_cache
        elsif %i[monotonic_growth linear_growth exponential_like].include?(trend[:pattern]) && !shrinking
          :unbounded_candidate
        elsif trend[:pattern] == :sawtooth
          :recovering_collection
        else
          :stable_or_noisy
        end

      {
        name: name,
        owner: owner,
        kind: kind,
        trend: trend,
        sizes: sizes,
        max: max_size,
        min: min_size
      }
    end

    def collection_findings(class_series)
      findings = []
      class_series.each_value do |entry|
        next unless %w[Array Hash Set].include?(entry[:name]) || entry[:name].end_with?("Registry", "Cache", "Store")

        classification = classify_collection_growth(name: entry[:name], sizes: entry[:series])
        case classification[:kind]
        when :unbounded_candidate
          findings << Finding.new(
            code: "HS004",
            severity: entry[:delta] > 200 ? :high : :medium,
            subject: entry[:name],
            facts: ["Observed fact: #{entry[:name]} sizes #{entry[:series].inspect}."],
            derived: [
              "Derived: pattern=#{classification[:trend][:pattern]}, no shrinkage observed across samples."
            ],
            hypothesis: "This structure is an unbounded collection candidate.",
            suggestions: [
              "Identify the owner/root retaining the collection",
              "Cap growth or add eviction",
              "Verify appends are not accidental per-request registrations"
            ],
            evidence: [classification]
          )
        when :likely_cache
          findings << Finding.new(
            code: "HS001",
            severity: :low,
            subject: entry[:name],
            title: "Likely cache plateau",
            facts: ["Observed fact: #{entry[:name]} reached a plateau near #{classification[:max]}."],
            derived: ["Derived: growth appears bounded (cache-like)."],
            hypothesis: "Intentional cache behavior is more likely than a leak.",
            suggestions: ["Confirm max size / LRU / TTL expectations"],
            evidence: [classification]
          )
        end
      end
      findings
    end

    def suspicious_key?(key)
      key.to_s.match?(/context|request|session|payload|current|job|controller|env/i)
    end

    def format_bytes(bytes)
      return "n/a" if bytes.nil?

      abs = bytes.abs.to_f
      if abs >= 1024 * 1024
        format("%.2f MB", abs / (1024 * 1024))
      elsif abs >= 1024
        format("%.1f KB", abs / 1024)
      else
        "#{bytes} B"
      end
    end
  end
end
