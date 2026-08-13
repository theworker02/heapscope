# frozen_string_literal: true

module HeapScope
  class CLI
    # Optional ANSI color for TTY output. Respects NO_COLOR and --no-color.
    module Color
      RESET = "\e[0m"
      BOLD = "\e[1m"
      DIM = "\e[2m"
      RED = "\e[31m"
      GREEN = "\e[32m"
      YELLOW = "\e[33m"
      CYAN = "\e[36m"
      MAGENTA = "\e[35m"

      module_function

      def enabled?(force: nil)
        return force unless force.nil?
        return false if ENV["NO_COLOR"] && !ENV["NO_COLOR"].empty?
        return false if ENV["TERM"].to_s == "dumb"

        $stdout.tty?
      rescue StandardError
        false
      end

      def wrap(text, code, enabled:)
        return text.to_s unless enabled && code

        "#{code}#{text}#{RESET}"
      end

      def severity(sev, enabled:)
        s = sev.to_s.upcase
        code =
          case sev.to_s.downcase.to_sym
          when :high then RED
          when :medium then YELLOW
          when :low then CYAN
          else DIM
          end
        wrap(s, code, enabled: enabled)
      end

      def ok(text, enabled:)
        wrap(text, GREEN, enabled: enabled)
      end

      def warn_text(text, enabled:)
        wrap(text, YELLOW, enabled: enabled)
      end

      def err(text, enabled:)
        wrap(text, RED, enabled: enabled)
      end

      def accent(text, enabled:)
        wrap(text, CYAN, enabled: enabled)
      end

      def bold(text, enabled:)
        wrap(text, BOLD, enabled: enabled)
      end
    end
  end
end
