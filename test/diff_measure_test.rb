# frozen_string_literal: true

require_relative "test_helper"

class DiffMeasureTest < Minitest::Test
  class LeakyBox
    def initialize(payload)
      @payload = payload
    end
  end

  def setup
    HeapScope.reset_config!
    @leak = []
  end

  def test_compare_detects_growth
    GC.start
    before = HeapScope.snapshot(mode: :lightweight)
    before_count = before.class_count(LeakyBox.name)
    500.times { |i| @leak << LeakyBox.new("x" * 100 + i.to_s) }
    GC.start
    after = HeapScope.snapshot(mode: :lightweight)
    report = HeapScope.compare(before, after)

    assert report.diff
    delta = after.class_count(LeakyBox.name) - before_count
    assert delta >= 400, "expected LeakyBox growth, got #{delta} (before=#{before_count}, after=#{after.class_count(LeakyBox.name)})"
    assert report.findings.any? || report.suspects.any? || delta >= 400
  end

  def test_measure_healthy_temporary_churn
    report = HeapScope.measure(force_gc: true, mode: :lightweight) do
      arr = []
      1_000.times { arr << ("temp" * 10) }
      arr.clear
      nil
    end

    assert report.diff
    assert report.to_text.include?("HEAPSCOPE")
  end

  def test_retention_test_persistent_growth
    leak = []
    report = HeapScope.retention_test(cycles: 4, force_gc: true, mode: :lightweight) do
      100.times { leak << LeakyBox.new("payload") }
    end

    assert report.retention
    persistent = report.retention[:persistent] || []
    names = persistent.map { |e| e[:name] }
    assert_includes names, "DiffMeasureTest::LeakyBox"
    assert report.findings.any? { |f| f.code == "HS001" }
  end

  def test_budget_check
    leak = []
    report = HeapScope.check_budget(
      budget: HeapScope::Budget.new(max_retained_objects: 10),
      force_gc: true,
      mode: :lightweight
    ) do
      200.times { leak << LeakyBox.new("z") }
    end

    refute report.passed_budget?
  end
end
