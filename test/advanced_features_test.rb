# frozen_string_literal: true

require_relative "test_helper"

class AdvancedFeaturesTest < Minitest::Test
  def setup
    HeapScope.reset_config!
  end

  def test_aging_buckets
    aging = HeapScope::Aging.new
    aging.push_counts(cycle: 0, counts: { "A" => 100, "B" => 100 })
    aging.push_counts(cycle: 1, counts: { "A" => 95, "B" => 10 })
    aging.push_counts(cycle: 2, counts: { "A" => 90, "B" => 2 })
    a = aging.classify("A")
    b = aging.classify("B")
    assert_equal :long_lived, a[:bucket]
    assert_equal :young, b[:bucket]
  end

  def test_fragmentation_assess
    snap = HeapScope.snapshot(mode: :lightweight)
    result = HeapScope::Fragmentation.assess(snap)
    assert result[:status]
    assert_match(/not confirmed/i, result[:note])
  end

  def test_yaml_config_load
    path = File.expand_path("../examples/heapscope.yml", __dir__)
    HeapScope.load_config!(path)
    assert_equal :standard, HeapScope.config.mode
  end

  def test_markdown_report
    before = HeapScope.snapshot(mode: :lightweight)
    after = HeapScope.snapshot(mode: :lightweight)
    report = HeapScope.compare(before, after)
    md = report.to_markdown
    assert_match(/# HeapScope Report/, md)
    assert_match(/Privacy/, md)
  end

  def test_doctor_and_overhead_api
    doc = HeapScope.doctor
    assert_equal HeapScope::VERSION, doc[:version]
    assert doc[:capabilities][:gc_stat]
    oh = HeapScope.overhead(mode: :lightweight, runs: 1)
    assert oh[:avg_seconds]
  end

  def test_paths_formatter
    path = HeapScope::Graph::Path.new(
      nodes: [{ via: "Thread" }, { via: "thread_variable[:ctx]" }, { via: "RequestContext" }],
      confidence: :low,
      note: "Nearest observed retainer"
    )
    text = HeapScope::Paths.format_tree(path)
    assert_match(/LIKELY RETENTION PATH/, text)
    assert_match(/RequestContext/, text)
  end

  def test_trend_store
    Dir.mktmpdir do |dir|
      path = File.join(dir, "trends.json")
      store = HeapScope::TrendStore.new(path)
      store.append({ time: Time.now.utc.iso8601, rss_bytes: 100, live_slots: 1000, top_class: "String" })
      store.append({ time: Time.now.utc.iso8601, rss_bytes: 120, live_slots: 1100, top_class: "String" })
      summary = store.summary
      assert_equal 2, summary[:samples]
      assert_equal 20, summary[:rss][:delta]
    end
  end

  def test_cli_doctor
    code = nil
    out = capture_io { code = HeapScope::CLI.new.run(["doctor"]) }.first
    assert_equal 0, code
    assert_match(/HeapScope doctor/, out)
  end

  def test_globals_inventory
    items = HeapScope::Globals.inventory(max_entries: 20)
    assert items.is_a?(Array)
  end

  def test_fibers_inventory
    items = HeapScope::Fibers.inventory
    assert items.is_a?(Array)
  end
end
