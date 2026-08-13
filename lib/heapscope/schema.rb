# frozen_string_literal: true

module HeapScope
  # Validates versioned report JSON payloads.
  module Schema
    REQUIRED_ROOT = %i[schema_version heapscope_version].freeze

    module_function

    def validate!(data)
      data = data.transform_keys(&:to_sym) if data.respond_to?(:transform_keys)
      missing = REQUIRED_ROOT.reject { |k| data.key?(k) }
      raise InvalidReportError, "Missing keys: #{missing.join(', ')}" unless missing.empty?

      version = data[:schema_version].to_i
      raise InvalidReportError, "Unsupported schema_version=#{version}" if version < 1 || version > SCHEMA_VERSION

      true
    end

    def valid?(data)
      validate!(data)
      true
    rescue InvalidReportError
      false
    end
  end
end
