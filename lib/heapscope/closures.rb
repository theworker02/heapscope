# frozen_string_literal: true

module HeapScope
  # Conservative Proc/closure retention analysis.
  # Ruby does not expose captured bindings cleanly — treat results as hypotheses.
  module Closures
    module_function

    def inventory(limit: 200)
      procs = []
      return procs unless Runtime.current.each_object?

      Runtime.current.each_object(Proc) do |proc|
        break if procs.size >= limit

        info = Runtime.current.allocation_info(proc)
        retained = begin
          Graph.new.estimate_retained_size(proc, max_objects: 500, max_depth: 4)
        rescue StandardError
          { retained: nil }
        end
        procs << {
          class: "Proc",
          lambda: proc.lambda?,
          arity: begin
            proc.arity
          rescue StandardError
            nil
          end,
          allocation: info,
          shallow_bytes: Runtime.current.memsize_of(proc),
          approx_retained: retained[:retained],
          approximate: true,
          note: "Closure captures are not fully introspectable — retained size is approximate."
        }
      end
      procs
    rescue StandardError
      []
    end

    def findings(procs)
      procs.select { |p| p[:approx_retained].to_i > 500_000 }.map do |p|
        site = p.dig(:allocation, :file) && "#{p[:allocation][:file]}:#{p[:allocation][:line]}"
        Finding.new(
          code: "HS006",
          severity: :medium,
          subject: site || "Proc",
          facts: [
            "Observed fact: Proc approx retained #{p[:approx_retained]} bytes" \
            "#{site ? " allocated at #{site}" : ""}."
          ],
          derived: ["Derived: bounded retained-size estimate exceeded 500KB."],
          hypothesis: "A long-lived Proc may be capturing a large object graph.",
          suspected_cause: site,
          suggestions: [
            "Avoid capturing large objects in long-lived callbacks",
            "Prefer weak refs or explicit clearable context objects"
          ],
          evidence: [p]
        )
      end
    end
  end

  # Fiber / execution-context awareness (best-effort).
  module Fibers
    module_function

    def inventory
      list = []
      if defined?(Fiber) && Fiber.respond_to?(:list)
        Fiber.list.each do |fiber|
          list << fiber_info(fiber)
        end
      elsif defined?(Fiber)
        list << fiber_info(Fiber.current)
      end
      list
    rescue StandardError => e
      [{ error: e.message }]
    end

    def fiber_info(fiber)
      storage =
        if fiber.respond_to?(:storage)
          fiber.storage
        else
          {}
        end
      {
        object_id: fiber.__id__,
        alive: (fiber.alive? if fiber.respond_to?(:alive?)),
        storage_keys: storage.respond_to?(:keys) ? storage.keys.map(&:inspect) : [],
        storage_size: storage.respond_to?(:size) ? storage.size : nil,
        note: "Fiber-local storage support varies by Ruby version."
      }
    rescue StandardError => e
      { error: e.message }
    end
  end
end
