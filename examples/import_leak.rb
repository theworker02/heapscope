# frozen_string_literal: true

require "bundler/setup"
require "heapscope"

# Demo: intentional leak via a growing array.
LEAK = []

puts "HeapScope #{HeapScope::VERSION}"
puts HeapScope.capabilities
puts

report = HeapScope.retention_test(cycles: 5, force_gc: true, mode: :lightweight) do
  200.times { LEAK << (+"item") << ("x" * 50) }
end

puts report
report.save("examples/import_leak_report.json")
puts "Wrote examples/import_leak_report.json"
