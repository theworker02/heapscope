# frozen_string_literal: true

module HeapScope
  # Evidence-based analyzer producing findings and suspect rankings.
  class Analyzer
    CHURN_THRESHOLD = 0.05
    STICKY_RETENTION = 0.30

    def initialize(config: HeapScope.config)
      @config = config
    end

    def analyze_diff(diff, context: {})
      findings = []
      suspects = []

      diff.growing_classes(30).each do |delta|
        next if @config.ignore_class?(delta[:name])
        next if delta[:delta_count] < 50 && delta[:delta_bytes] < 100_000

        classification = classify_population(delta, diff)
        severity = suspicion_for(delta, classification, context)

        suspects << {
          name: delta[:name],
          severity: severity,
          delta_count: delta[:delta_count],
          delta_bytes: delta[:delta_bytes],
          classification: classification,
          retention_ratio: context.dig(:retention_by_class, delta[:name])
        }

        next unless delta[:delta_count] >= 100
        next if classification == :high_churn_low_retention
        next if classification == :normal && severity == :low

        findings << Finding.new(
          code: "HS001",
          severity: severity,
          subject: delta[:name],
          facts: [
            "Observed fact: #{delta[:name]} count #{delta[:before_count]} → #{delta[:after_count]} (Δ #{signed(delta[:delta_count])})."
          ],
          derived: [
            "Derived: shallow bytes Δ #{format_bytes(delta[:delta_bytes])}."
          ],
          hypothesis: "This population appears to be growing across the measured window.",
          suspected_cause: nil,
          evidence: [delta],
          suggestions: [
            "Compare against a post-GC snapshot",
            "Run HeapScope.retention_test to check multi-cycle survival",
            "Inspect allocation sites for #{delta[:name]}"
          ]
        )
      end

      if diff.retention_ratio && diff.retention_ratio > 0.2 && diff.allocated_delta.to_i > 1000
        findings << Finding.new(
          code: "HS002",
          severity: :high,
          facts: [
            "Observed fact: allocated Δ #{diff.allocated_delta}, freed Δ #{diff.freed_delta}."
          ],
          derived: [
            "Derived: retention ratio #{pct(diff.retention_ratio)} (surviving estimate #{diff.surviving_estimate})."
          ],
          hypothesis: "A meaningful fraction of allocations remained reachable after the workload.",
          suggestions: [
            "Force GC between snapshots if not already doing so",
            "Identify top retained classes and their owners"
          ]
        )
      end

      if diff.native_memory_mismatch?
        findings << Finding.new(
          code: "HS010",
          severity: :medium,
          facts: [
            "Observed fact: RSS Δ #{format_bytes(diff.rss_delta)}; heap live slots Δ #{diff.heap_live_delta}."
          ],
          derived: [
            "Derived: Ruby heap growth does not explain RSS growth."
          ],
          hypothesis: "Native allocations, allocator fragmentation, mmap, or extension buffers may be involved.",
          suggestions: [
            "Do not assume an object leak from RSS alone",
            "Inspect native extensions and allocator (jemalloc/glibc/macOS)"
          ]
        )
      end

      if high_churn?(diff)
        findings << Finding.new(
          code: "HS009",
          severity: :low,
          facts: [
            "Observed fact: allocated Δ #{diff.allocated_delta}, freed Δ #{diff.freed_delta}."
          ],
          derived: ["Derived: high allocation pressure with substantial reclamation."],
          hypothesis: "Workload exhibits object churn rather than persistent retention.",
          suggestions: ["Optimize hot allocation sites if CPU/GC time is a concern"]
        )
      end

      ranked = Findings.rank_and_dedupe(findings)
      {
        findings: ranked,
        suspects: suspects.sort_by { |s| [-severity_rank(s[:severity]), -s[:delta_count]] },
        summary: build_summary(diff, ranked, suspects)
      }
    end

    def analyze_retention(session)
      findings = []
      persistent = session.persistent_classes
      persistent.first(10).each do |entry|
        next if @config.ignore_class?(entry[:name])

        findings << Finding.new(
          code: "HS001",
          severity: entry[:delta] > 500 ? :high : :medium,
          subject: entry[:name],
          facts: [
            "Observed fact: #{entry[:name]} series #{entry[:series].inspect}."
          ],
          derived: [
            "Derived: pattern=#{entry[:trend][:pattern]}, slope=#{entry[:trend][:slope]} objects/sample."
          ],
          hypothesis: "Persistent growth across GC-sampled cycles is consistent with retention.",
          suggestions: [
            "Locate allocation site for #{entry[:name]}",
            "Inspect thread-locals, globals, and registries for owners"
          ]
        )
      end

      if session.force_gc && persistent.any?
        findings << Finding.new(
          code: "HS007",
          severity: :medium,
          facts: ["Observed fact: forced GC between samples; persistent classes still grew."],
          derived: ["Derived: recovery after GC appears poor for top populations."],
          hypothesis: "Growth is not explained by delayed GC alone."
        )
      end

      series = session.class_series
      findings.concat(Detectors.collection_findings(series))

      thread_local = Detectors.analyze_thread_locals
      findings.concat(thread_local[:findings])

      findings = Findings.rank_and_dedupe(findings)
      {
        findings: findings,
        persistent: persistent,
        class_series: series,
        thread_locals: thread_local[:inventory],
        collections: series.values.map { |e|
          Detectors.classify_collection_growth(name: e[:name], sizes: e[:series])
        }.select { |c| %i[likely_cache unbounded_candidate].include?(c[:kind]) },
        summary: {
          samples: session.samples.size,
          persistent_count: persistent.size,
          top: persistent.first(5).map { |e| { name: e[:name], delta: e[:delta], pattern: e[:trend][:pattern] } }
        }
      }
    end

    # Extra deep enrichment for retention sessions (globals, fibers, aging, etc.).
    def enrich_session(session, last_snapshot)
      findings = []
      limitations = []
      cfg = @config

      Noise.apply_defaults! if cfg.apply_noise_defaults

      fibers = cfg.detect_fibers ? Fibers.inventory : []
      globals = cfg.detect_globals ? Globals.inventory(max_entries: 100) : []
      closures =
        if cfg.detect_closures
          Closures.inventory(limit: 50)
        else
          limitations << "closure_detection_disabled"
          []
        end
      findings.concat(Closures.findings(closures)) if cfg.detect_closures

      dominators =
        begin
          Dominators.new.from_thread_locals(limit: 5)
        rescue StandardError => e
          limitations << "dominators_unavailable:#{e.class}"
          []
        end

      fragmentation = last_snapshot ? Fragmentation.assess(last_snapshot) : nil
      if fragmentation && fragmentation[:status] == :potential_fragmentation
        findings << Finding.new(
          code: "HS010",
          severity: :low,
          facts: ["Observed fact: RSS/heap ratio indicator=#{fragmentation[:rss_to_heap_ratio]}."],
          derived: ["Derived: status=#{fragmentation[:status]}."],
          hypothesis: fragmentation[:note],
          suggestions: ["Investigate allocator / native extensions before blaming Ruby objects"]
        )
      end

      aging = Aging.new
      session.samples.each_with_index do |sample, idx|
        counts = sample.snapshot.class_stats.transform_values { |s| s[:count].to_i }
        aging.push_counts(cycle: idx, counts: counts, generation_hint: sample.snapshot.gc_generation)
      end

      gc_correlation = {
        samples: session.samples.size,
        first_live: session.samples.first&.snapshot&.heap_live_slots,
        last_live: session.samples.last&.snapshot&.heap_live_slots,
        first_rss: session.samples.first&.snapshot&.rss_bytes,
        last_rss: session.samples.last&.snapshot&.rss_bytes
      }

      retention_paths = []
      if dominators.any?
        retention_paths << {
          summary: "Top approximate retainers from thread-locals",
          retainers: dominators.map { |d| { class: d.class_name, approx_retained: d.approx_retained, note: d.note } }
        }
      end

      {
        findings: findings,
        fibers: fibers,
        globals: globals,
        closures: closures.first(20),
        dominators: dominators,
        fragmentation: fragmentation,
        aging: aging.report(top: 15),
        gc_correlation: gc_correlation,
        retention_paths: retention_paths,
        limitations: limitations
      }
    end

    def classify_population(delta, diff)
      allocated = diff.allocated_delta.to_i
      retained = delta[:delta_count]
      ratio = allocated.positive? ? retained.to_f / allocated : nil

      if ratio && ratio < CHURN_THRESHOLD && allocated > 10_000
        :high_churn_low_retention
      elsif ratio && ratio > STICKY_RETENTION
        :sticky
      elsif retained > 1000 && allocated > 10_000 && ratio && ratio > 0.1
        :severe
      else
        :normal
      end
    end

    def suspicion_for(delta, classification, context)
      return :low if classification == :high_churn_low_retention

      score = 0
      score += 2 if delta[:delta_count] > 500
      score += 2 if %i[sticky severe].include?(classification)
      score += 1 if context[:force_gc]
      score += 1 if context.dig(:survival_cycles, delta[:name]).to_i >= 3
      score -= 2 if context.dig(:likely_cache, delta[:name])
      score -= 1 if @config.ignore_class?(delta[:name])

      case score
      when ...1 then :low
      when 1..3 then :medium
      else :high
      end
    end

    private

    def high_churn?(diff)
      allocated = diff.allocated_delta.to_i
      freed = diff.freed_delta.to_i
      allocated > 50_000 && freed > allocated * 0.9
    end

    def build_summary(diff, findings, suspects)
      actionable = findings.reject { |f| f.code == "HS009" }
      healthy = actionable.none? { |f| %i[high medium].include?(f.severity) } &&
                suspects.none? { |s| s[:severity] == :high }
      {
        healthy: healthy,
        rss_delta: diff.rss_delta,
        heap_live_delta: diff.heap_live_delta,
        retention_ratio: diff.retention_ratio,
        top_suspects: suspects.first(5),
        finding_codes: findings.map(&:code)
      }
    end

    def severity_rank(sev)
      { high: 3, medium: 2, low: 1 }[sev] || 0
    end

    def signed(n)
      n.positive? ? "+#{n}" : n.to_s
    end

    def pct(ratio)
      format("%.2f%%", ratio * 100.0)
    end

    def format_bytes(bytes)
      return "n/a" if bytes.nil?

      abs = bytes.abs.to_f
      sign = if bytes.negative?
               "-"
             else
               (bytes.positive? ? "+" : "")
             end
      if abs >= 1024 * 1024
        format("%s%.2f MB", sign, abs / (1024 * 1024))
      elsif abs >= 1024
        format("%s%.1f KB", sign, abs / 1024)
      else
        format("%s%d B", sign, bytes)
      end
    end
  end
end
