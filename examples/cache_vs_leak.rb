# frozen_string_literal: true

require "bundler/setup"
require "heapscope"

# Bounded cache vs unbounded registry — HeapScope should treat them differently.
CACHE = {}
CACHE_MAX = 100
REGISTRY = []

def fill_cache
  300.times { |i| CACHE[i % CACHE_MAX] = "v#{i}" }
end

def fill_registry
  150.times { REGISTRY << ("row-" + rand(10_000).to_s) }
end

puts "=== CACHE (expect plateau / low suspicion) ==="
cache_report = HeapScope.retention_test(cycles: 5, force_gc: true, mode: :lightweight) { fill_cache }
puts cache_report.summary.inspect
puts cache_report.findings.map { |f| "#{f.code}/#{f.severity}" }.inspect

puts
puts "=== REGISTRY (expect persistent growth) ==="
reg_report = HeapScope.retention_test(cycles: 5, force_gc: true, mode: :lightweight) { fill_registry }
puts reg_report.summary.inspect
puts reg_report.findings.map { |f| "#{f.code}/#{f.severity} #{f.subject}" }.inspect

reg_report.save_html("examples/cache_vs_leak.html")
