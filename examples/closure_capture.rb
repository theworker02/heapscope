# frozen_string_literal: true

require "bundler/setup"
require "heapscope"

# Closure capture demo — enable closure detection explicitly.
HOLDERS = []
big = Array.new(2_000) { "payload" }

HeapScope.configure do |c|
  c.detect_closures = true
end

report = HeapScope.retention_test(cycles: 4, force_gc: true, mode: :lightweight) do
  30.times { HOLDERS << -> { big.size } }
end

puts report
puts "Closures sampled: #{Array(report.closures).size}"
report.save_markdown("examples/closure_report.md")
