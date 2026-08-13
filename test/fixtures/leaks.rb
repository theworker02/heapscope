# frozen_string_literal: true

# Synthetic leak fixtures for evaluating HeapScope detection.

module HeapScopeFixtures
  module ThreadLocalLeak
    def self.run(n = 200)
      Thread.current[:heapscope_fixture_context] ||= { items: [] }
      n.times { Thread.current[:heapscope_fixture_context][:items] << ("leak" * 20) }
    end

    def self.clear
      Thread.current[:heapscope_fixture_context] = nil
    end
  end

  class RegistryItem
    def initialize(payload)
      @payload = payload
    end
  end

  module GlobalArrayLeak
    REGISTRY = []

    def self.run(n = 200)
      n.times { |i| REGISTRY << RegistryItem.new("item-#{i}") }
    end

    def self.clear
      REGISTRY.clear
    end
  end

  module SubscriberLeak
    LISTENERS = []

    def self.run(n = 50)
      n.times { LISTENERS << ->(event) { event } }
    end

    def self.clear
      LISTENERS.clear
    end
  end

  module CachePlateau
    CACHE = {}
    MAX = 100

    def self.run(n = 200)
      n.times do |i|
        CACHE[i % MAX] = "value-#{i}"
      end
    end

    def self.clear
      CACHE.clear
    end
  end

  module ClosureCapture
    HOLDERS = []

    def self.run(n = 50)
      big = Array.new(1_000) { "data" }
      n.times do
        HOLDERS << -> { big.size }
      end
    end

    def self.clear
      HOLDERS.clear
    end
  end

  module TemporaryChurn
    def self.run(n = 5_000)
      n.times { |i| ("churn" * 10) + i.to_s }
      nil
    end
  end
end
