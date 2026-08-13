# frozen_string_literal: true

module HeapScope
  module Runtime
    # Shared runtime adapter interface. Implementations degrade safely.
    class Base
      attr_reader :engine

      def initialize(engine: RUBY_ENGINE)
        @engine = engine
      end

      def allocation_tracing?
        false
      end

      def reachable_objects?
        false
      end

      def memsize?
        false
      end

      def rss_tracking?
        rss_bytes
        true
      rescue StandardError
        false
      end

      def each_object?
        false
      end

      def gc_stat?
        defined?(GC) && GC.respond_to?(:stat)
      end

      def gc_stat
        return {} unless gc_stat?

        normalize_gc_stat(GC.stat)
      end

      def rss_bytes
        read_rss_bytes
      end

      def each_object(_klass = nil)
        raise CapabilityError, "ObjectSpace.each_object is unavailable on #{engine}"
      end

      def memsize_of(_object)
        nil
      end

      def reachable_objects_from(_object)
        []
      end

      def start_allocation_tracing
        raise CapabilityError, "Allocation tracing unavailable on #{engine}"
      end

      def stop_allocation_tracing
        nil
      end

      def allocation_info(_object)
        nil
      end

      def process_metadata
        {
          pid: Process.pid,
          ppid: Process.ppid,
          engine: engine,
          ruby: RUBY_VERSION,
          platform: RUBY_PLATFORM,
          thread: Thread.current.name || Thread.current.object_id.to_s
        }
      end

      private

      INTERESTING_GC_KEYS = %i[
        count time major_gc_count minor_gc_count
        heap_live_slots heap_free_slots heap_available_slots heap_allocatable_slots
        heap_allocated_pages heap_eden_pages heap_tomb_pages heap_sorted_length
        total_allocated_objects total_freed_objects
        malloc_increase_bytes malloc_increase_bytes_limit
        old_objects oldmalloc_increase_bytes remembered_wb_unprotected_objects
      ].freeze

      def normalize_gc_stat(raw)
        INTERESTING_GC_KEYS.each_with_object({}) do |key, hash|
          hash[key] = raw[key] if raw.key?(key)
        end
      end

      def read_rss_bytes
        if File.readable?("/proc/self/status")
          line = File.foreach("/proc/self/status").find { |l| l.start_with?("VmRSS:") }
          return line.split[1].to_i * 1024 if line
        end

        macos_rss || windows_rss
      end

      def macos_rss
        return nil unless RUBY_PLATFORM.include?("darwin")

        out = `ps -o rss= -p #{Process.pid} 2>/dev/null`.to_s.strip
        return nil if out.empty?

        out.to_i * 1024
      end

      def windows_rss
        return nil unless RUBY_PLATFORM.match?(/mswin|mingw|cygwin/i)

        require_relative "windows_rss"
        WindowsRSS.working_set_bytes
      rescue StandardError
        nil
      end
    end
  end
end
