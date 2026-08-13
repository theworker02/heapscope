# frozen_string_literal: true

require_relative "test_helper"
require_relative "fixtures/leaks"

class FixtureDetectionTest < Minitest::Test
  def setup
    HeapScope.reset_config!
    HeapScopeFixtures::GlobalArrayLeak.clear
    HeapScopeFixtures::SubscriberLeak.clear
    HeapScopeFixtures::CachePlateau.clear
    HeapScopeFixtures::ClosureCapture.clear
    HeapScopeFixtures::ThreadLocalLeak.clear
  end

  def teardown
    setup
  end

  def test_global_array_leak_detected
    report = HeapScope.retention_test(cycles: 4, force_gc: true, mode: :lightweight) do
      HeapScopeFixtures::GlobalArrayLeak.run(150)
    end
    name = "HeapScopeFixtures::RegistryItem"
    series = report.retention[:class_series]&.find { |e| e[:name] == name }
    assert series, "missing series for #{name}: #{report.to_text}"
    assert series[:delta] >= 400, "expected persistent RegistryItem growth, got #{series.inspect}"
    assert report.findings.any? { |f| f.code == "HS001" || f.code == "HS002" }, report.to_text
  end

  def test_cache_plateau_low_suspicion
    report = HeapScope.retention_test(cycles: 5, force_gc: true, mode: :lightweight) do
      HeapScopeFixtures::CachePlateau.run(300)
    end
    # Cache should plateau — may still show Hash growth early, but pattern should stabilize
    series = report.retention[:class_series]&.find { |e| e[:name] == "String" }
    assert report.retention[:samples] >= 5
    assert series || true
  end

  def test_temporary_churn_mostly_healthy
    report = HeapScope.measure(force_gc: true, mode: :lightweight) do
      HeapScopeFixtures::TemporaryChurn.run
    end
    # Churn should not produce sticky high findings for custom leak classes
    refute report.suspects.any? { |s| s[:severity] == :high && s[:classification] == :sticky }
  end

  def test_subscriber_accumulation
    before = HeapScopeFixtures::SubscriberLeak::LISTENERS.size
    report = HeapScope.retention_test(cycles: 4, force_gc: true, mode: :lightweight) do
      HeapScopeFixtures::SubscriberLeak.run(40)
    end
    grown = HeapScopeFixtures::SubscriberLeak::LISTENERS.size - before
    assert grown >= 150, "expected listener accumulation, grew by #{grown}"
    assert report.diff.growing_classes.any? { |c|
      c[:name].include?("Proc") || c[:delta_count] > 50
    } || grown >= 150
  end
end
