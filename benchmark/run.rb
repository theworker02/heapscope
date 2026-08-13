# frozen_string_literal: true

require "bundler/setup"
require "heapscope"

puts "Measuring snapshot overhead..."

%i[lightweight standard deep].each do |mode|
  times = 3.times.map do
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    snap = HeapScope.snapshot(mode: mode, max_objects: 50_000, max_pause: 2_000)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
    [elapsed, snap.class_stats.size, snap.duration_ms]
  end
  avg = times.map(&:first).sum / times.size
  puts format("%-12s avg=%.3fs classes≈%d self_ms≈%.1f", mode, avg, times.last[1], times.last[2])
end
