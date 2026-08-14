# frozen_string_literal: true

require_relative "heapscope/version"
require_relative "heapscope/errors"
require_relative "heapscope/config"
require_relative "heapscope/capabilities"
require_relative "heapscope/runtime"
require_relative "heapscope/snapshot"
require_relative "heapscope/collector"
require_relative "heapscope/diff"
require_relative "heapscope/growth"
require_relative "heapscope/findings"
require_relative "heapscope/analyzer"
require_relative "heapscope/retention"
require_relative "heapscope/graph"
require_relative "heapscope/report"
require_relative "heapscope/budget"
require_relative "heapscope/baseline"
require_relative "heapscope/monitor"
require_relative "heapscope/detectors"
require_relative "heapscope/extrapolation"
require_relative "heapscope/aging"
require_relative "heapscope/globals"
require_relative "heapscope/closures"
require_relative "heapscope/dominators"
require_relative "heapscope/noise"
require_relative "heapscope/notifications"
require_relative "heapscope/paths"
require_relative "heapscope/trend_store"
require_relative "heapscope/scorecard"
require_relative "heapscope/session"
require_relative "heapscope/tables"
require_relative "heapscope/schema"
require_relative "heapscope/branding"
require_relative "heapscope/suggest"
require_relative "heapscope/catalog"
require_relative "heapscope/pack"
require_relative "heapscope/flamegraph"

# HeapScope — Ruby object retention, heap growth, and memory leak diagnostics.
#
# Distinguishes allocation pressure from retention, and intentional retention
# from suspicious patterns. Prefers evidence over certainty.
module HeapScope
  class << self
    def snapshot(mode: nil, **opts)
      Collector.new.capture(mode: mode, **opts)
    end

    def compare(before, after, metadata: {})
      before = Snapshot.load(before) if before.is_a?(String)
      after = Snapshot.load(after) if after.is_a?(String)
      diff = Diff.new(before, after)
      analysis = Analyzer.new.analyze_diff(diff, context: metadata)
      Report.from_diff(diff, analysis: analysis, metadata: metadata)
    end

    def measure(force_gc: config.force_gc_default, mode: nil, recovery_wait: nil,
                track_allocations: config.track_allocations, metadata: {})
      raise ArgumentError, "block required" unless block_given?

      tracer = AllocationTracer.new
      tracing = track_allocations && tracer.available?
      tracer.start! if tracing

      GC.start if force_gc
      before = snapshot(mode: mode || :standard, metadata: metadata.merge(phase: "before"))

      allocated_before = Runtime.current.gc_stat[:total_allocated_objects]
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
      allocated_after = Runtime.current.gc_stat[:total_allocated_objects]

      immediately_after = snapshot(mode: mode || :standard, metadata: metadata.merge(phase: "immediately_after"))

      GC.start if force_gc
      after_gc = snapshot(mode: mode || :standard, metadata: metadata.merge(phase: "after_gc"))

      after_idle = nil
      if recovery_wait&.positive?
        sleep recovery_wait
        GC.start if force_gc
        after_idle = snapshot(mode: mode || :lightweight, metadata: metadata.merge(phase: "after_idle"))
      end

      final = after_idle || after_gc
      diff = Diff.new(before, final)
      analysis = Analyzer.new.analyze_diff(
        diff,
        context: metadata.merge(force_gc: force_gc)
      )

      allocated = (allocated_after || 0) - (allocated_before || 0)
      rate = elapsed.positive? ? (allocated / elapsed) : nil

      report = Report.from_diff(
        diff,
        analysis: analysis,
        metadata: metadata.merge(
          kind: "measure",
          force_gc: force_gc,
          elapsed_seconds: elapsed.round(4),
          objects_allocated_during: allocated,
          allocation_rate_per_sec: rate&.round(1),
          phases: {
            before: before.id,
            immediately_after: immediately_after.id,
            after_gc: after_gc.id,
            after_idle: after_idle&.id
          }.compact,
          recovery: recovery_stats(before, immediately_after, after_gc, after_idle),
          block_result_class: result.class.name
        )
      )
      report
    ensure
      tracer&.stop! if tracing
    end

    def retention_test(cycles: 5, force_gc: true, mode: :lightweight, metadata: {})
      raise ArgumentError, "block required" unless block_given?

      session = RetentionSession.new(force_gc: force_gc, mode: mode, metadata: metadata)
      session.sample(label: "baseline")
      cycles.times do |i|
        yield
        session.sample(label: "cycle_#{i + 1}")
      end
      report = session.finish
      # Enrich metadata
      report.metadata[:kind] = "retention_test"
      report.metadata[:cycles] = cycles
      report
    end

    def experiment(runs: 10, force_gc: true, mode: :lightweight, metadata: {}, &block)
      raise ArgumentError, "block required" unless block_given?

      results = runs.times.map do |i|
        measure(force_gc: force_gc, mode: mode, metadata: metadata.merge(run: i), &block)
      end

      retained = results.map { |r| r.diff&.surviving_estimate.to_i }
      rss = results.map { |r| r.diff&.rss_delta.to_i }
      stats = lambda do |arr|
        sorted = arr.sort
        {
          min: sorted.first,
          max: sorted.last,
          median: percentile(sorted, 50),
          p95: percentile(sorted, 95),
          mean: (arr.sum.to_f / arr.size).round(2),
          variance: Growth.sample_variance(arr.map(&:to_f)).round(2)
        }
      end

      Report.new(
        runtime_info: { ruby: RUBY_VERSION, engine: RUBY_ENGINE },
        summary: {
          healthy: results.all?(&:healthy?),
          runs: runs,
          retained_objects: stats.call(retained),
          rss_delta: stats.call(rss)
        },
        findings: results.flat_map(&:findings).uniq { |f| [f.code, f.subject] },
        suspects: results.flat_map(&:suspects).group_by { |s| s[:name] }.map do |_name, list|
          list.max_by { |s| s[:delta_count] }.merge(runs_seen: list.size)
        end,
        metadata: metadata.merge(kind: "experiment", runs: runs),
        before: results.first&.before,
        after: results.last&.after,
        diff: results.last&.diff,
        classes: results.last&.classes || []
      )
    end

    def repeat(times, force_gc: true, mode: :lightweight, &block)
      retention_test(cycles: times, force_gc: force_gc, mode: mode, &block)
    end

    # Soft check — always returns a report with budget_result.
    def check_budget(budget:, force_gc: true, mode: :standard, metadata: {}, &block)
      raise ArgumentError, "block required" unless block

      report = measure(force_gc: force_gc, mode: mode, metadata: metadata, &block)
      result = budget.evaluate(report)
      Report.new(
        schema_version: report.schema_version,
        heapscope_version: report.heapscope_version,
        runtime_info: report.runtime_info,
        summary: report.summary.merge(budget_passed: result[:passed]),
        before: report.before,
        after: report.after,
        diff: report.diff,
        findings: report.findings,
        suspects: report.suspects,
        classes: report.classes,
        allocation_sites: report.allocation_sites,
        retention: report.retention,
        metadata: report.metadata,
        limitations: report.limitations,
        budget_result: result,
        reproduction: report.reproduction
      )
    end

    # Like check_budget, but raises BudgetExceededError on failure.
    def check(budget:, **opts, &block)
      report = check_budget(budget: budget, **opts, &block)
      return report if report.passed_budget?

      raise BudgetExceededError, report.budget_result[:violations].join("; ")
    end

    def capabilities
      Capabilities.new(Runtime.current)
    end

    def runtime
      Runtime.current
    end

    def doctor
      {
        version: VERSION,
        ruby: RUBY_VERSION,
        engine: RUBY_ENGINE,
        platform: RUBY_PLATFORM,
        capabilities: capabilities.to_h,
        config: {
          mode: config.mode,
          ignore_patterns: config.ignore_patterns.map(&:inspect)
        }
      }
    end

    def overhead(mode: :lightweight, runs: 3)
      Overhead.measure_snapshot(mode: mode, runs: runs)
    end

    def probe(title: "probe", **opts, &block)
      Probe.run(title: title, **opts, &block)
    end

    def session(name, root: Dir.pwd)
      Session.open(name, root: root)
    end

    def scorecard(report, title: "HeapScope")
      Scorecard.from_report(report, title: title)
    end

    def codes
      Catalog.codes
    end

    def about
      Branding.about_text
    end

    def branding
      Branding.to_h
    end

    def suggest_ignores(report)
      Suggest.ignore_patterns(report)
    end

    def next_steps(report, limit: 8)
      Suggest.next_steps(report, limit: limit)
    end

    def budget_preset(name)
      Budget.preset(name)
    end

    def pack(report, dir, label: "heapscope-report")
      Pack.export(report, dir, label: label)
    end

    def write_config!(path = "heapscope.yml", force: false)
      ConfigLoader.write_starter!(path, force: force)
    end

    def flamegraph(snapshot, unit: :count)
      Flamegraph.from_snapshot(snapshot, unit: unit)
    end

    private

    def recovery_stats(before, immediate, after_gc, after_idle)
      {
        baseline_rss: before.rss_bytes,
        peak_rss: immediate.rss_bytes,
        after_gc_rss: after_gc.rss_bytes,
        after_idle_rss: after_idle&.rss_bytes,
        baseline_live: before.heap_live_slots,
        peak_live: immediate.heap_live_slots,
        after_gc_live: after_gc.heap_live_slots,
        after_idle_live: after_idle&.heap_live_slots
      }
    end

    def percentile(sorted, pct)
      return nil if sorted.empty?

      k = ((pct / 100.0) * (sorted.size - 1)).round
      sorted[k]
    end
  end
end
