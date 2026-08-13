# frozen_string_literal: true

module HeapScope
  class Error < StandardError; end

  class UnsupportedRuntimeError < Error; end
  class SnapshotError < Error; end
  class InvalidReportError < Error; end
  class CapabilityError < Error; end
  class AnalysisLimitError < Error; end
  class ConfigurationError < Error; end
  class BudgetExceededError < Error; end
end
