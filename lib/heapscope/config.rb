# frozen_string_literal: true

module HeapScope
  class Config
    MODES = %i[lightweight standard deep production_safe development].freeze
    SNAPSHOT_MODES = %i[lightweight standard deep].freeze

    attr_accessor :mode,
                  :track_allocations,
                  :max_graph_depth,
                  :max_objects,
                  :max_edges,
                  :max_pause_ms,
                  :object_sample_rate,
                  :force_gc_default,
                  :include_runtime_objects,
                  :ignore_patterns,
                  :ignored_classes,
                  :inspect_values,
                  :verbose,
                  :debug,
                  :rails,
                  :redactor,
                  :logger,
                  :warmup_done,
                  :min_retention_cycles,
                  :detect_globals,
                  :detect_closures,
                  :detect_fibers,
                  :detect_thread_locals,
                  :apply_noise_defaults,
                  :quiet

    def initialize
      @mode = :standard
      @track_allocations = false
      @max_graph_depth = 6
      @max_objects = 100_000
      @max_edges = 500_000
      @max_pause_ms = nil
      @object_sample_rate = 1.0
      @force_gc_default = false
      @include_runtime_objects = false
      @ignore_patterns = [/^HeapScope::/]
      @ignored_classes = []
      @inspect_values = false
      @verbose = false
      @debug = false
      @rails = false
      @redactor = nil
      @logger = nil
      @warmup_done = false
      @min_retention_cycles = 3
      @detect_globals = true
      @detect_closures = false
      @detect_fibers = true
      @detect_thread_locals = true
      @apply_noise_defaults = true
      @quiet = false
    end

    def production_safe?
      mode == :production_safe
    end

    def development?
      mode == :development
    end

    def effective_snapshot_mode(requested = nil)
      requested ||= snapshot_mode_for_config
      return :lightweight if production_safe? && requested == :deep

      requested
    end

    def snapshot_mode_for_config
      case mode
      when :lightweight, :production_safe then :lightweight
      when :deep, :development then :deep
      else :standard
      end
    end

    def ignore_class?(name)
      return true if ignored_classes.map(&:to_s).include?(name.to_s)

      ignore_patterns.any? { |pattern| name.to_s.match?(pattern) }
    end

    def redact(object)
      return nil unless inspect_values
      return redactor.call(object) if redactor

      :"[redacted]"
    end

    def log(level, message)
      return unless logger || verbose || debug
      return if level == :debug && !debug

      (logger || $stderr).puts("[HeapScope] #{message}")
    end
  end

  # Load Ruby or YAML configuration files.
  module ConfigLoader
    STARTER_YAML = <<~YAML
      # HeapScope local config — no telemetry, no uploads
      heapscope:
        mode: standard
        track_allocations: false
        apply_noise_defaults: true
        detect_globals: true
        detect_fibers: true
        detect_closures: false
        detect_thread_locals: true
        retention:
          min_cycles: 3
        ignore_patterns:
          - "^Zeitwerk"
          - "^Bootsnap"
          - "^HeapScope::"
    YAML

    module_function

    def load!(path)
      raise ConfigurationError, "Config not found: #{path}" unless File.exist?(path)

      case File.extname(path)
      when ".yml", ".yaml"
        load_yaml!(path)
      when ".rb"
        load(path)
      else
        raise ConfigurationError, "Unsupported config type: #{path}"
      end
      HeapScope.config
    end

    def load_yaml!(path)
      require "yaml"
      data = YAML.safe_load_file(path, permitted_classes: [Symbol], aliases: true) || {}
      data = data["heapscope"] || data[:heapscope] || data
      HeapScope.configure do |c|
        c.mode = data["mode"]&.to_sym if data["mode"]
        c.track_allocations = data["track_allocations"] unless data["track_allocations"].nil?
        c.max_graph_depth = data["max_graph_depth"] if data["max_graph_depth"]
        c.max_objects = data["max_objects"] if data["max_objects"]
        c.object_sample_rate = data["object_sample_rate"] if data["object_sample_rate"]
        Array(data["ignore_patterns"]).each { |p| c.ignore_patterns << Regexp.new(p) }
        c.min_retention_cycles = data.dig("retention", "min_cycles") if data.dig("retention", "min_cycles")
        c.detect_globals = data["detect_globals"] unless data["detect_globals"].nil?
        c.detect_closures = data["detect_closures"] unless data["detect_closures"].nil?
        c.detect_fibers = data["detect_fibers"] unless data["detect_fibers"].nil?
        c.apply_noise_defaults = data["apply_noise_defaults"] unless data["apply_noise_defaults"].nil?
      end
    end

    def write_starter!(path = "heapscope.yml", force: false)
      raise ConfigurationError, "Refusing to overwrite existing #{path}" if File.exist?(path) && !force

      File.write(path, STARTER_YAML)
      path
    end
  end

  class << self
    def config
      @config ||= Config.new
    end

    def configure
      yield config
      self
    end

    def reset_config!
      @config = Config.new
    end

    def ignore_class(klass)
      config.ignored_classes << klass
    end

    def after_warmup
      yield if block_given?
      config.warmup_done = true
    end

    def load_config!(path)
      ConfigLoader.load!(path)
    end
  end
end
