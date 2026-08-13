# frozen_string_literal: true

require "bundler/setup"
require "heapscope"

# Demonstrates thread-local retention across "requests" on one thread.
HeapScopeFixtures = Module.new unless defined?(HeapScopeFixtures)

module ThreadLocalDemo
  def self.handle_request
    Thread.current[:request_context] ||= { presenters: [] }
    50.times do
      Thread.current[:request_context][:presenters] << ("Presenter:" + ("x" * 40))
    end
  end

  def self.clear
    Thread.current[:request_context] = nil
  end
end

ThreadLocalDemo.clear

report = HeapScope.retention_test(cycles: 6, force_gc: true, mode: :lightweight) do
  ThreadLocalDemo.handle_request
end

puts report
report.save("examples/thread_local_report.json")
report.save_html("examples/thread_local_report.html")
puts "Wrote examples/thread_local_report.{json,html}"
