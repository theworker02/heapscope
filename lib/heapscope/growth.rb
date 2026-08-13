# frozen_string_literal: true

module HeapScope
  # Detects growth patterns across samples. Evidence-based, not magical.
  module Growth
    module_function

    PATTERNS = %i[
      stable bursty linear_growth monotonic_growth sawtooth
      exponential_like bounded_plateau insufficient_data
    ].freeze

    def analyze(samples)
      values = samples.map(&:to_f)
      return result(:insufficient_data, values) if values.size < 3

      slope = linear_slope(values)
      variance = sample_variance(values)
      mean = values.sum / values.size
      recovering = sawtooth?(values)
      plateau = plateau?(values)
      monotonic = monotonic?(values)
      exponential = exponential_like?(values)

      relative_span = mean.positive? ? (values.max - values.min) / mean : 0

      pattern =
        if recovering
          :sawtooth
        elsif plateau && values.max > values.first * 1.5
          :bounded_plateau
        elsif exponential
          :exponential_like
        elsif monotonic && slope > 0 && !exponential
          :monotonic_growth
        elsif relative_span < 0.05 || (slope.abs < [mean * 0.02, 1.0].max && variance < (mean * 0.05)**2)
          :stable
        elsif slope > 0
          :linear_growth
        elsif variance > (mean * 0.3)**2
          :bursty
        else
          :stable
        end

      result(pattern, values, slope: slope)
    end

    def result(pattern, values, slope: 0.0)
      {
        pattern: pattern,
        slope: slope.round(3),
        samples: values,
        min: values.min,
        max: values.max,
        mean: values.empty? ? 0.0 : (values.sum / values.size).round(3),
        recovery_after_gc: pattern == :sawtooth ? :observed : :minimal
      }
    end

    def linear_slope(values)
      n = values.size
      xs = (0...n).map(&:to_f)
      x_mean = xs.sum / n
      y_mean = values.sum / n
      num = xs.zip(values).sum { |x, y| (x - x_mean) * (y - y_mean) }
      den = xs.sum { |x| (x - x_mean)**2 }
      return 0.0 if den.zero?

      num / den
    end

    def sample_variance(values)
      return 0.0 if values.size < 2

      mean = values.sum / values.size
      values.sum { |v| (v - mean)**2 } / (values.size - 1)
    end

    def monotonic?(values)
      values.each_cons(2).all? { |a, b| b >= a }
    end

    def sawtooth?(values)
      drops = values.each_cons(2).count { |a, b| b < a * 0.7 }
      rises = values.each_cons(2).count { |a, b| b > a }
      drops >= 1 && rises >= 2
    end

    def plateau?(values)
      return false if values.size < 5

      last = values.last(3)
      span = last.max - last.min
      early_growth = values[2] >= values.first * 1.5
      span <= [last.max * 0.05, 2].max && early_growth
    end

    def exponential_like?(values)
      return false unless monotonic?(values) && values.first.positive?
      return false if values.size < 4

      ratios = values.each_cons(2).map { |a, b| a.positive? ? b / a : 0 }
      # Require accelerating growth, not merely a steady linear climb.
      ratios.size >= 3 && ratios.all? { |r| r >= 1.4 } && ratios.last >= ratios.first
    end
  end
end
