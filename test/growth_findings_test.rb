# frozen_string_literal: true

require_relative "test_helper"

class GrowthFindingsTest < Minitest::Test
  def test_monotonic_growth_pattern
    result = HeapScope::Growth.analyze([10, 20, 30, 40, 50])
    assert_equal :monotonic_growth, result[:pattern]
    assert result[:slope] > 0
  end

  def test_stable_pattern
    result = HeapScope::Growth.analyze([100, 101, 99, 100, 102])
    assert_equal :stable, result[:pattern]
  end

  def test_plateau_pattern
    result = HeapScope::Growth.analyze([10, 50, 100, 100, 101, 100])
    assert_equal :bounded_plateau, result[:pattern]
  end

  def test_exponential_pattern
    result = HeapScope::Growth.analyze([10, 20, 40, 80, 160])
    assert_equal :exponential_like, result[:pattern]
  end

  def test_finding_structure
    finding = HeapScope::Finding.new(
      code: "HS003",
      severity: :high,
      facts: ["Observed fact: thread local grew."],
      derived: ["Derived: survived 5 cycles."],
      hypothesis: "Thread-local context retains presenters.",
      suspected_cause: "Thread.current[:context]",
      suggestions: ["clear thread locals"]
    )
    h = finding.to_h
    assert_equal "HS003", h[:code]
    assert_equal "thread_local_retention", h[:name]
    assert h[:facts]
    assert h[:hypothesis]
  end

  def test_native_mismatch_detection
    before = HeapScope.snapshot(mode: :lightweight)
    after = HeapScope::Snapshot.new(
      id: "x",
      timestamp: Time.now.utc,
      mode: :lightweight,
      gc_stat: before.gc_stat.merge(
        heap_live_slots: before.heap_live_slots.to_i + 10,
        total_allocated_objects: before.total_allocated_objects.to_i + 10,
        total_freed_objects: before.total_freed_objects.to_i + 5
      ),
      rss_bytes: before.rss_bytes.to_i + (50 * 1024 * 1024),
      class_stats: before.class_stats,
      process: before.process
    )
    diff = HeapScope::Diff.new(before, after)
    assert diff.native_memory_mismatch?
    analysis = HeapScope::Analyzer.new.analyze_diff(diff)
    assert analysis[:findings].any? { |f| f.code == "HS010" }
  end
end
