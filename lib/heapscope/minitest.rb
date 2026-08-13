# frozen_string_literal: true

require "heapscope"

# Optional Minitest helpers: require "heapscope/minitest"
module HeapScope
  module Minitest
    def assert_heapscope_retained_under(limit, force_gc: true, klass: nil, &block)
      report = HeapScope.measure(force_gc: force_gc, &block)
      actual = klass ? report.retained_count_for(klass) : report.diff&.surviving_estimate.to_i
      assert actual < limit,
             "expected retained objects < #{limit}, got #{actual}. " \
             "Suspects: #{report.suspects.first(5).map { |s| s[:name] }.join(', ')}"
      report
    end

    def assert_heapscope_bytes_under(limit, force_gc: true, &block)
      report = HeapScope.measure(force_gc: force_gc, &block)
      actual = report.diff&.heap_bytes_estimate_delta.to_i
      assert actual < limit,
             "expected retained bytes < #{limit}, got #{actual}"
      report
    end

    def assert_heapscope_budget(budget, **opts, &)
      report = HeapScope.check_budget(budget: budget, **opts, &)
      assert report.passed_budget?, report.budget_result[:violations].join("\n")
      report
    end

    def assert_heapscope_healthy(force_gc: true, &block)
      report = HeapScope.measure(force_gc: force_gc, &block)
      assert report.healthy? || report.findings.none? { |f| f.severity == :high },
             "expected healthy profile, got #{report.findings.map(&:code)}"
      report
    end

    def assert_heapscope_no_code(code, force_gc: true, &block)
      report = HeapScope.measure(force_gc: force_gc, &block)
      refute report.findings.any? { |f| f.code == code },
             "expected no #{code}, got #{report.findings.map(&:code)}"
      report
    end
  end
end

Minitest::Test.include HeapScope::Minitest if defined?(Minitest::Test)
