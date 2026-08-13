# frozen_string_literal: true

module HeapScope
  # Optional ActiveSupport::Notifications adapter — not required in core.
  module Notifications
    module_function

    def available?
      defined?(ActiveSupport::Notifications)
    end

    def subscriber_counts
      raise CapabilityError, "ActiveSupport::Notifications not loaded" unless available?

      # Best-effort: AS does not always expose a public subscriber registry.
      # We sample notifier internals when present, otherwise return empty.
      notifier = ActiveSupport::Notifications.notifier
      counts = Hash.new(0)
      if notifier.respond_to?(:listeners_for)
        # Can't enumerate all patterns easily — return structure placeholder
        { note: "Use listen_growth to track specific patterns over time." }
      elsif notifier.instance_variable_defined?(:@subscribers)
        Array(notifier.instance_variable_get(:@subscribers)).each do |sub|
          pattern = begin
            sub.respond_to?(:pattern) ? sub.pattern : sub.class.name
          rescue StandardError
            "unknown"
          end
          counts[pattern.to_s] += 1
        end
        counts
      else
        { note: "Subscriber registry not introspectable on this Rails version." }
      end
    end

    # Track a specific notification pattern count via wrapping — records samples.
    class GrowthProbe
      def initialize(pattern)
        @pattern = pattern
        @samples = []
        @count = 0
        @sub = nil
      end

      def start!
        raise CapabilityError, "ActiveSupport::Notifications not loaded" unless Notifications.available?

        @sub = ActiveSupport::Notifications.subscribe(@pattern) { @_count = (@_count || 0) + 1 }
        self
      end

      def sample!
        # Prefer explicit counter if subscribe block used; otherwise inventory
        @samples << (@_count || 0)
        @samples.last
      end

      def finish
        ActiveSupport::Notifications.unsubscribe(@sub) if @sub
        series = @samples
        trend = Growth.analyze(series)
        finding =
          if %i[monotonic_growth linear_growth exponential_like].include?(trend[:pattern])
            Finding.new(
              code: "HS005",
              severity: :high,
              subject: @pattern.to_s,
              facts: ["Observed fact: notification #{@pattern} sample counts #{series.inspect}."],
              derived: ["Derived: pattern=#{trend[:pattern]}."],
              hypothesis: "Possible repeated registration without unsubscribe.",
              suggestions: ["Register subscribers once at boot", "Unsubscribe on teardown"]
            )
          end
        { series: series, trend: trend, finding: finding }
      end
    end
  end
end
