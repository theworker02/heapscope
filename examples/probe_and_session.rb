# frozen_string_literal: true

require "bundler/setup"
require "heapscope"

puts "Probe demo"
result = HeapScope.probe(title: "temporary objects", force_gc: true, mode: :lightweight) do
  data = []
  5_000.times { |i| data << { i: i } }
  data.clear
  nil
end
puts result.scorecard.to_text

puts
puts "Session demo"
session = HeapScope.session("demo-probe")
session.measure(label: "churn", force_gc: true, mode: :lightweight) do
  1_000.times { "x" * 10 }
end
puts "Session artifacts in .heapscope/sessions/demo-probe/"
puts "Latest: #{session.latest.inspect}"
