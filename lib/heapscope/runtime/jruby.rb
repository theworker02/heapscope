# frozen_string_literal: true

require_relative "base"

module HeapScope
  module Runtime
    # Placeholder adapter — JRuby introspection differs from MRI.
    class JRuby < Base
      def initialize
        super(engine: "jruby")
      end

      def each_object?
        defined?(ObjectSpace) && ObjectSpace.respond_to?(:each_object)
      end

      def each_object(klass = nil, &)
        raise CapabilityError, "ObjectSpace.each_object unavailable on JRuby" unless each_object?

        if klass
          ObjectSpace.each_object(klass, &)
        else
          ObjectSpace.each_object(&)
        end
      end
    end
  end
end
