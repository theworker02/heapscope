# frozen_string_literal: true

require "set"

module HeapScope
  # Global / constant / class-variable retention candidates.
  module Globals
    module_function

    def inventory(max_entries: 200)
      items = []
      items.concat(global_variables_inventory)
      items.concat(constant_registry_hints)
      items.first(max_entries)
    rescue StandardError => e
      [{ error: e.message }]
    end

    def global_variables_inventory
      global_variables.map do |name|
        next if name == :$= # deprecated / noisy

        value = begin
          eval(name.to_s) # rubocop:disable Security/Eval -- inspecting known global variable names only
        rescue StandardError
          nil
        end
        next if value.nil?

        {
          kind: :global_variable,
          name: name.to_s,
          class: value.class.name,
          size_hint: size_hint(value),
          shallow_bytes: Runtime.current.memsize_of(value)
        }
      end.compact
    end

    def constant_registry_hints
      suspects = []
      Object.constants.each do |const_name|
        const = begin
          Object.const_get(const_name)
        rescue StandardError
          next
        end
        next unless const.is_a?(Module)

        %i[REGISTRY CACHE STORE HANDLERS LISTENERS SUBSCRIBERS].each do |hint|
          next unless const.const_defined?(hint, false)

          value = const.const_get(hint)
          suspects << {
            kind: :constant,
            name: "#{const.name}::#{hint}",
            class: value.class.name,
            size_hint: size_hint(value),
            shallow_bytes: Runtime.current.memsize_of(value)
          }
        end
      rescue StandardError
        next
      end
      suspects
    end

    def growing_findings(previous:, current:)
      findings = []
      prev_map = previous.to_h { |i| [i[:name], i] }
      current.each do |item|
        before = prev_map[item[:name]]
        next unless before

        before_size = before[:size_hint].to_i
        after_size = item[:size_hint].to_i
        next unless after_size > before_size + 50

        findings << Finding.new(
          code: "HS004",
          severity: after_size > before_size * 2 ? :high : :medium,
          subject: item[:name],
          facts: [
            "Observed fact: #{item[:name]} size hint #{before_size} → #{after_size}."
          ],
          derived: ["Derived: global/constant collection grew between samples."],
          hypothesis: "A module-level registry or global collection may be accumulating entries.",
          suspected_cause: item[:name],
          suggestions: [
            "Bound or clear #{item[:name]}",
            "Confirm intentional caching vs accidental append"
          ],
          evidence: [{ before: before, after: item }]
        )
      end
      findings
    end

    def size_hint(value)
      case value
      when Array, Hash, Set then value.size
      else 1
      end
    rescue StandardError
      0
    end
  end
end
