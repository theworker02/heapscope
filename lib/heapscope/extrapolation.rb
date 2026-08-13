# frozen_string_literal: true

module HeapScope
  # Extrapolates retention rate into a labeled estimate. Never presented as guaranteed.
  module Extrapolation
    module_function

    def retention_per_hour(retained_bytes:, elapsed_seconds:)
      return nil if elapsed_seconds.nil? || elapsed_seconds <= 0 || retained_bytes.nil?

      rate = retained_bytes.to_f / elapsed_seconds
      {
        bytes_per_second: rate.round(2),
        bytes_per_hour: (rate * 3600).round,
        label: "extrapolation",
        caveat: "At the current observed retention rate — not a prediction of future usage."
      }
    end

    def objects_per_run(retained_objects:, runs:)
      return nil if runs.nil? || runs <= 0

      {
        retained_objects_per_run: (retained_objects.to_f / runs).round(2),
        label: "per-run retention"
      }
    end
  end

  # Classifies churn vs sticky populations for reports.
  module Classification
    module_function

    def churn_vs_leak(allocated:, retained:)
      allocated = allocated.to_i
      retained = retained.to_i
      return :insufficient_data if allocated <= 0

      ratio = retained.to_f / allocated
      if allocated > 10_000 && ratio < 0.05
        :high_churn_low_retention
      elsif allocated < 1_000 && ratio > 0.5
        :sticky
      elsif allocated > 10_000 && ratio > 0.3
        :severe
      else
        :normal
      end
    end
  end
end
