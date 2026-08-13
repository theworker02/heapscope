# frozen_string_literal: true

module HeapScope
  # Known framework / VM noise filters. Affects findings, not raw snapshot data.
  module Noise
    DEFAULT_PATTERNS = [
      /^RubyVM/,
      /^Zeitwerk/,
      /^Bootsnap/,
      /^ActiveSupport::Dependencies/,
      /^Module$/,
      /^Class$/,
      /^HeapScope::/
    ].freeze

    # Extra framework hints used by Suggest (never auto-applied to config).
    FRAMEWORK_HINTS = [
      /^ActiveSupport::/,
      /^ActiveRecord::ConnectionAdapters/,
      /^ActionDispatch::/,
      /^ActionController::/,
      /^ActionView::/,
      /^Rack::/,
      /^Sidekiq::/,
      /^Concurrent::/
    ].freeze

    module_function

    def default_patterns
      DEFAULT_PATTERNS.dup
    end

    def suggestion_patterns
      DEFAULT_PATTERNS + FRAMEWORK_HINTS
    end

    def noisy?(name, patterns: HeapScope.config.ignore_patterns)
      patterns.any? { |p| name.to_s.match?(p) }
    end

    def apply_defaults!
      DEFAULT_PATTERNS.each do |pattern|
        HeapScope.config.ignore_patterns << pattern unless HeapScope.config.ignore_patterns.include?(pattern)
      end
    end
  end
end
