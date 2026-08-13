# frozen_string_literal: true

module HeapScope
  # Bounded reachability / retention-path analysis for deep mode.
  # Never fabricates roots; reports nearest observed retainer when uncertain.
  class Graph
    Node = Struct.new(:local_id, :class_name, :ruby_object_id, :label, keyword_init: true)
    Edge = Struct.new(:from, :to, :via, keyword_init: true)
    Path = Struct.new(:nodes, :confidence, :note, keyword_init: true)

    def initialize(runtime: Runtime.current, config: HeapScope.config)
      @runtime = runtime
      @config = config
    end

    def available?
      @runtime.reachable_objects?
    end

    # BFS for a short human-understandable retention path from known roots.
    def retention_path(target, roots: nil, max_depth: nil, max_edges: nil)
      max_depth ||= @config.max_graph_depth
      max_edges ||= @config.max_edges
      return unavailable_path("reachable_objects API unavailable") unless available?

      roots ||= default_roots
      visited = {}
      parent = {}
      via = {}
      queue = []
      edges = 0
      target_id = target.__id__

      roots.each do |root, label|
        id = root.__id__
        next if visited[id]

        visited[id] = true
        queue << root
        parent[id] = nil
        via[id] = label
      end

      found = nil
      while (current = queue.shift)
        break if edges >= max_edges

        depth = depth_of(current.__id__, parent)
        next if depth >= max_depth

        children = safe_reachable(current)
        children.each_with_index do |child, idx|
          edges += 1
          break if edges >= max_edges

          cid = child.__id__
          next if visited[cid]

          visited[cid] = true
          parent[cid] = current.__id__
          via[cid] = edge_label(current, child, idx)
          queue << child
          if cid == target_id
            found = child
            break
          end
        end
        break if found
      end

      if found
        build_path(found, parent, via, :high, "Bounded BFS path from known roots")
      else
        nearest = nearest_retainer(target)
        Path.new(
          nodes: nearest,
          confidence: :low,
          note: "Nearest observed retainer; true root not identified within budget"
        )
      end
    rescue AnalysisLimitError => e
      Path.new(nodes: [], confidence: :low, note: e.message)
    end

    def estimate_retained_size(root, max_objects: nil, max_depth: nil)
      max_objects ||= [@config.max_objects, 10_000].min
      max_depth ||= @config.max_graph_depth
      return { shallow: @runtime.memsize_of(root), retained: nil, note: "unavailable" } unless available?

      seen = {}
      total = 0
      count = 0
      queue = [[root, 0]]
      seen[root.__id__] = true

      while (pair = queue.shift)
        obj, depth = pair
        count += 1
        break if count >= max_objects

        total += @runtime.memsize_of(obj).to_i
        next if depth >= max_depth

        safe_reachable(obj).each do |child|
          cid = child.__id__
          next if seen[cid]

          seen[cid] = true
          queue << [child, depth + 1]
        end
      end

      {
        shallow: @runtime.memsize_of(root),
        retained: total,
        objects: count,
        approximate: true,
        note: "Approximate retained size via bounded traversal"
      }
    end

    def thread_local_inventory
      Thread.list.map do |thread|
        keys =
          if thread.respond_to?(:keys)
            thread.keys
          else
            []
          end
        values = keys.each_with_object({}) do |key, hash|
          value = thread[key]
          hash[key.inspect] = {
            class: value.class.name,
            shallow_bytes: @runtime.memsize_of(value)
          }
        rescue StandardError
          hash[key.inspect] = { class: "unknown" }
        end

        {
          name: thread.name || "thread-#{thread.object_id}",
          status: thread.status,
          keys: values
        }
      end
    end

    def unbounded_collection_candidates(_samples)
      # samples: array of { object_local_id/class/size } or class series sizes for Array/Hash
      []
    end

    private

    def default_roots
      roots = []
      roots << [Object, "constant:Object"]
      begin
        Thread.list.each { |t| roots << [t, "thread:#{t.name || t.object_id}"] }
      rescue StandardError
        nil
      end
      roots << [Fiber.current, "fiber:current"] if defined?(Fiber) && Fiber.respond_to?(:current)
      roots
    end

    def safe_reachable(object)
      @runtime.reachable_objects_from(object).grep(Object)
    rescue StandardError
      []
    end

    def edge_label(parent, _child, index)
      case parent
      when Hash then "hash_entry"
      when Array then "array[#{index}]"
      when Thread then "thread_reference"
      else "ivars/refs"
      end
    end

    def depth_of(id, parent)
      d = 0
      cur = id
      while parent[cur]
        d += 1
        cur = parent[cur]
        break if d > 10_000
      end
      d
    end

    def build_path(target, parent, via, confidence, note)
      cur = target.__id__
      chain = []
      while cur
        chain << cur
        cur = parent[cur]
      end
      nodes = chain.reverse.map do |id|
        { object_id: id, via: via[id] }
      end
      Path.new(nodes: nodes, confidence: confidence, note: note)
    end

    def nearest_retainer(target)
      refs = safe_reachable(target)
      [{ class: target.class.name, note: "target" }] +
        refs.first(5).map { |o| { class: o.class.name, note: "reachable_neighbor" } }
    rescue StandardError
      [{ class: target.class.name, note: "target_only" }]
    end

    def unavailable_path(note)
      Path.new(nodes: [], confidence: :low, note: note)
    end
  end
end
