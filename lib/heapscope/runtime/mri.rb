# frozen_string_literal: true

require "objspace"
require_relative "base"

module HeapScope
  module Runtime
    class MRI < Base
      def initialize
        super(engine: "ruby")
      end

      def allocation_tracing?
        ObjectSpace.respond_to?(:trace_object_allocations_start)
      end

      def reachable_objects?
        ObjectSpace.respond_to?(:reachable_objects_from)
      end

      def memsize?
        ObjectSpace.respond_to?(:memsize_of)
      end

      def each_object?
        ObjectSpace.respond_to?(:each_object)
      end

      def each_object(klass = nil, &)
        raise CapabilityError, "ObjectSpace.each_object unavailable" unless each_object?

        if klass
          ObjectSpace.each_object(klass, &)
        else
          ObjectSpace.each_object(&)
        end
      end

      def memsize_of(object)
        return nil unless memsize?

        ObjectSpace.memsize_of(object)
      rescue StandardError
        nil
      end

      def reachable_objects_from(object)
        return [] unless reachable_objects?

        ObjectSpace.reachable_objects_from(object) || []
      rescue StandardError
        []
      end

      def start_allocation_tracing
        raise CapabilityError, "Allocation tracing unavailable" unless allocation_tracing?

        ObjectSpace.trace_object_allocations_start
      end

      def stop_allocation_tracing
        return unless allocation_tracing?

        ObjectSpace.trace_object_allocations_stop
      end

      def allocation_info(object)
        return nil unless allocation_tracing?

        file = ObjectSpace.allocation_sourcefile(object)
        line = ObjectSpace.allocation_sourceline(object)
        return nil unless file

        {
          file: file,
          line: line,
          generation: (ObjectSpace.allocation_generation(object) if ObjectSpace.respond_to?(:allocation_generation)),
          class_path: (ObjectSpace.allocation_class_path(object) if ObjectSpace.respond_to?(:allocation_class_path)),
          method_id: (ObjectSpace.allocation_method_id(object) if ObjectSpace.respond_to?(:allocation_method_id))
        }.compact
      rescue StandardError
        nil
      end
    end
  end
end
