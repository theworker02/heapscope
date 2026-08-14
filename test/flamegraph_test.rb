# frozen_string_literal: true

require_relative "test_helper"

class FlamegraphTest < Minitest::Test
  def setup
    HeapScope.reset_config!
  end

  def test_current_product_version
    assert_equal "0.7.0", HeapScope::VERSION
  end

  def test_folded_stacks_group_classes_under_allocation_sites
    graph = HeapScope.flamegraph(sample_snapshot)

    folded = graph.to_folded
    assert_includes folded, "/app/job.rb:12;perform;String 8"
    assert_includes folded, "/app/job.rb:12;perform;Array 2"
    assert_equal 10, graph.total
    refute graph.empty?
  end

  def test_speedscope_profile_is_sampled_json
    graph = HeapScope.flamegraph(sample_snapshot, unit: :bytes)
    payload = graph.to_speedscope

    assert_equal "sampled", payload[:profiles].first[:type]
    assert_equal "bytes", payload[:profiles].first[:unit]
    assert_equal 100, payload[:profiles].first[:endValue]
    assert(payload[:shared][:frames].any? { |frame| frame[:name].include?("job.rb:12") })
  end

  def test_cli_flamegraph_writes_folded_output
    Dir.mktmpdir do |dir|
      path = File.join(dir, "snap.json")
      sample_snapshot.save(path)
      out_path = File.join(dir, "alloc.folded")
      code = nil
      capture_io do
        code = HeapScope::CLI.new.run(["flamegraph", path, "-o", out_path, "--format", "folded"])
      end
      assert_equal 0, code
      body = File.read(out_path)
      assert_includes body, "String 8"
    end
  end

  private

  def sample_snapshot
    HeapScope::Snapshot.new(
      id: "fg-test",
      timestamp: Time.now.utc,
      mode: :standard,
      gc_stat: {},
      rss_bytes: 1_024,
      class_stats: {},
      allocation_sites: {
        "/app/job.rb:12" => {
          site: "/app/job.rb:12",
          count: 10,
          shallow_bytes: 100,
          classes: { "String" => 8, "Array" => 2 },
          method_id: "perform"
        }
      }
    )
  end
end
