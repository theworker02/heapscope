# frozen_string_literal: true

require_relative "runtime/base"
require_relative "runtime/mri"
require_relative "runtime/jruby"
require_relative "runtime/truffleruby"

module HeapScope
  module Runtime
    module_function

    def current
      @current ||= detect
    end

    def reset!
      @current = nil
    end

    def detect
      case RUBY_ENGINE
      when "ruby"
        MRI.new
      when "jruby"
        JRuby.new
      when "truffleruby"
        TruffleRuby.new
      else
        Base.new(engine: RUBY_ENGINE)
      end
    end
  end
end
