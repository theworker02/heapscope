# frozen_string_literal: true

require "bundler/setup"
require "heapscope"

# Healthy temporary allocation — should reclaim after GC.
report = HeapScope.measure(force_gc: true, mode: :lightweight) do
  data = []
  10_000.times { |i| data << { i: i, body: "x" * 20 } }
  data.clear
  nil
end

# Framework/Hash noise from the profiler itself is ignored in findings by default.
puts report
puts "Healthy?=#{report.summary[:healthy].inspect} findings=#{report.findings.map(&:code)}"
