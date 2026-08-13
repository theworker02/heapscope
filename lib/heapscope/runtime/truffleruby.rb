# frozen_string_literal: true

require_relative "base"

module HeapScope
  module Runtime
    # Placeholder adapter — TruffleRuby support may expand later.
    class TruffleRuby < Base
      def initialize
        super(engine: "truffleruby")
      end

      def each_object?
        defined?(ObjectSpace) && ObjectSpace.respond_to?(:each_object)
      end

      def memsize?
        defined?(ObjectSpace) && ObjectSpace.respond_to?(:memsize_of)
      end

      def each_object(klass = nil, &)
        raise CapabilityError, "ObjectSpace.each_object unavailable on TruffleRuby" unless each_object?

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
    end
  end
end
