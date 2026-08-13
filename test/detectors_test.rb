# frozen_string_literal: true

require_relative "test_helper"

class DetectorsTest < Minitest::Test
  def test_unbounded_collection_classification
    result = HeapScope::Detectors.classify_collection_growth(
      name: "EventRegistry",
      sizes: [100, 200, 300, 420]
    )
    assert_equal :unbounded_candidate, result[:kind]
  end

  def test_cache_plateau_classification
    result = HeapScope::Detectors.classify_collection_growth(
      name: "MyCache",
      sizes: [10, 50, 100, 100, 100]
    )
    assert_equal :likely_cache, result[:kind]
  end

  def test_extrapolation_labeled
    ext = HeapScope::Extrapolation.retention_per_hour(retained_bytes: 10_000_000, elapsed_seconds: 60)
    assert ext[:bytes_per_hour].positive?
    assert_equal "extrapolation", ext[:label]
    assert_match(/not a prediction/i, ext[:caveat])
  end

  def test_thread_local_inventory_runs
    Thread.current[:heapscope_test_key] = { bulky: "x" * 100 }
    result = HeapScope::Detectors.analyze_thread_locals
    assert result[:inventory].is_a?(Array)
  ensure
    Thread.current[:heapscope_test_key] = nil
  end
end
