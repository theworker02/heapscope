# frozen_string_literal: true

module HeapScope
  # Runtime capability probe. Never claims unavailable features exist.
  class Capabilities
    ATTRS = %i[
      engine
      ruby_version
      allocation_tracing
      reachable_objects
      memsize
      rss_tracking
      each_object
      gc_stat
      dump_all
      object_id_stable_across_restart
    ].freeze

    attr_reader(*ATTRS)

    def initialize(runtime)
      @engine = runtime.engine
      @ruby_version = RUBY_VERSION
      @allocation_tracing = runtime.allocation_tracing?
      @reachable_objects = runtime.reachable_objects?
      @memsize = runtime.memsize?
      @rss_tracking = runtime.rss_tracking?
      @each_object = runtime.each_object?
      @gc_stat = runtime.gc_stat?
      @dump_all = false
      @object_id_stable_across_restart = false
    end

    def to_h
      ATTRS.to_h { |key| [key, public_send(key)] }
    end

    def to_s
      to_h.map { |k, v| "#{k}: #{v}" }.join("\n")
    end
  end
end
