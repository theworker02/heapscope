# frozen_string_literal: true

require "heapscope"

# Optional RSpec matchers: require "heapscope/rspec"
module HeapScope
  module RSpecMatchers
    class RetainLessThan
      def initialize(limit)
        @limit = limit
        @unit = :objects
        @klass = nil
        @report = nil
      end

      def objects
        @unit = :objects
        self
      end

      def bytes
        @unit = :bytes
        self
      end

      def of(klass)
        @klass = klass
        self
      end

      def matches?(proc)
        @report = HeapScope.measure(force_gc: true) { proc.call }
        @actual =
          if @klass
            @unit == :bytes ? @report.retained_bytes_for(@klass) : @report.retained_count_for(@klass)
          elsif @unit == :bytes
            @report.diff&.heap_bytes_estimate_delta.to_i
          else
            @report.diff&.surviving_estimate.to_i
          end
        @actual < @limit
      end

      def failure_message
        suspects = Array(@report&.suspects).first(5).map { |s| "#{s[:name]}(+#{s[:delta_count]})" }.join(", ")
        "expected retained #{@unit}#{@klass ? " of #{@klass}" : ""} < #{@limit}, got #{@actual}. Suspects: #{suspects}"
      end

      def failure_message_when_negated
        "expected retained #{@unit} >= #{@limit}, got #{@actual}"
      end

      def supports_block_expectations?
        true
      end
    end

    class GrowHeapByMoreThan
      def initialize(bytes)
        @bytes = bytes
        @report = nil
      end

      def matches?(proc)
        @report = HeapScope.measure(force_gc: true) { proc.call }
        @actual = @report.diff&.heap_bytes_estimate_delta.to_i
        @actual > @bytes
      end

      def failure_message
        "expected heap growth > #{@bytes}, got #{@actual}"
      end

      def failure_message_when_negated
        suspects = Array(@report&.suspects).first(5).map { |s| "#{s[:name]}(+#{s[:delta_count]})" }.join(", ")
        "expected heap not to grow by more than #{@bytes}, got #{@actual}. Suspects: #{suspects}"
      end

      def supports_block_expectations?
        true
      end
    end

    class RemainHealthy
      def matches?(proc)
        @report = HeapScope.measure(force_gc: true) { proc.call }
        @report.healthy? && @report.findings.none? { |f| f.severity == :high }
      end

      def failure_message
        codes = @report.findings.map { |f| "#{f.code}/#{f.severity}" }.join(", ")
        "expected healthy retention profile, findings: #{codes}"
      end

      def supports_block_expectations?
        true
      end
    end

    def retain_less_than(limit)
      RetainLessThan.new(limit)
    end

    def grow_heap_by_more_than(bytes)
      GrowHeapByMoreThan.new(bytes)
    end

    def heapscope_remain_healthy
      RemainHealthy.new
    end
  end
end

if defined?(RSpec)
  RSpec.configure do |config|
    config.include HeapScope::RSpecMatchers
  end
end
