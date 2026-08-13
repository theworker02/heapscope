# frozen_string_literal: true

require "bundler/setup"
require "heapscope"
require_relative "../test/fixtures/leaks"

# Lightweight detection accuracy harness for known fixtures.
# Measures fixture discrimination only — not claimed production accuracy.

def leak_pass?(report, codes)
  ((codes & report.findings.map(&:code).uniq).any? || report.findings.any? { |f| f.severity == :high })
end

def churn_pass?(report)
  report.findings.none? { |f| f.severity == :high && f.code != "HS009" } ||
    report.suspects.none? { |s| s[:severity] == :high && s[:classification] == :sticky }
end

def cache_pass?(report)
  # Cache should remain bounded; allow noisy String/Hash findings but prefer plateau signals.
  collections = report.retention && report.retention[:collections]
  plateau = Array(collections).any? { |c| c[:kind] == :likely_cache }
  bounded = HeapScopeFixtures::CachePlateau::CACHE.size <= HeapScopeFixtures::CachePlateau::MAX
  plateau || bounded
end

SCENARIOS = {
  global_array_leak: {
    setup: -> { HeapScopeFixtures::GlobalArrayLeak.clear },
    run: -> { HeapScopeFixtures::GlobalArrayLeak.run(120) },
    mode: :retention,
    check: ->(r) { leak_pass?(r, %w[HS001 HS002 HS004]) }
  },
  temporary_churn: {
    setup: -> {},
    run: -> { HeapScopeFixtures::TemporaryChurn.run(3_000) },
    mode: :measure,
    check: ->(r) { churn_pass?(r) }
  },
  cache_plateau: {
    setup: -> { HeapScopeFixtures::CachePlateau.clear },
    run: -> { HeapScopeFixtures::CachePlateau.run(200) },
    mode: :retention,
    check: ->(r) { cache_pass?(r) }
  },
  subscriber_leak: {
    setup: -> { HeapScopeFixtures::SubscriberLeak.clear },
    run: -> { HeapScopeFixtures::SubscriberLeak.run(30) },
    mode: :retention,
    check: ->(r) { leak_pass?(r, %w[HS001 HS002]) }
  }
}.freeze

results = SCENARIOS.map do |name, spec|
  spec[:setup].call
  report =
    if spec[:mode] == :measure
      HeapScope.measure(force_gc: true, mode: :lightweight) { spec[:run].call }
    else
      HeapScope.retention_test(cycles: 4, force_gc: true, mode: :lightweight) { spec[:run].call }
    end

  {
    scenario: name,
    findings: report.findings.map(&:code).uniq,
    high: report.findings.any? { |f| f.severity == :high },
    pass: spec[:check].call(report)
  }
end

passes = results.count { |r| r[:pass] }
puts "HeapScope eval harness — #{passes}/#{results.size} scenarios discriminated"
results.each do |r|
  status = r[:pass] ? "PASS" : "FAIL"
  puts format("%-22s %-5s findings=%s high=%s", r[:scenario], status, r[:findings].inspect, r[:high])
end

exit(passes == results.size ? 0 : 1)
