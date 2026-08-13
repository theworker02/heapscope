# frozen_string_literal: true

module HeapScope
  # Optional Rails helpers. Loaded explicitly: require "heapscope/rails"
  module Rails
    module_function

    def install_middleware!(sample_rate: 0.01)
      raise CapabilityError, "Rails is not loaded" unless defined?(::Rails)

      ::Rails.application.config.middleware.use(
        HeapScope::Middleware,
        sample_rate: sample_rate
      )
    end

    def request_retention(label: "request", cycles: 10, force_gc: true, &block)
      raise ArgumentError, "block required" unless block_given?

      HeapScope.retention_test(
        cycles: cycles,
        force_gc: force_gc,
        metadata: { kind: "rails_request", label: label }, &block
      )
    end

    def measure_action(controller:, action:, force_gc: true, &block)
      raise ArgumentError, "block required" unless block_given?

      HeapScope.measure(
        force_gc: force_gc,
        metadata: {
          kind: "rails_action",
          controller: controller.to_s,
          action: action.to_s,
          label: "#{controller}##{action}"
        }, &block
      )
    end

    def activerecord_population
      return {} unless defined?(::ActiveRecord::Base)

      counts = {}
      ObjectSpace.each_object(Class) do |klass|
        next unless klass < ::ActiveRecord::Base
        next if klass.abstract_class?

        counts[klass.name] = ObjectSpace.each_object(klass).count
      rescue StandardError
        next
      end
      counts
    rescue StandardError
      {}
    end

    def warn_if_autoloading!
      return unless defined?(::Rails)
      return unless ::Rails.respond_to?(:application)
      return unless ::Rails.env.development?

      HeapScope.config.log(
        :verbose,
        "Rails development autoloading can distort heap growth. Prefer warmups or cache_classes for experiments."
      )
    end
  end
end

require_relative "middleware"
