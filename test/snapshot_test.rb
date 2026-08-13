# frozen_string_literal: true

require_relative "test_helper"

class SnapshotTest < Minitest::Test
  def setup
    HeapScope.reset_config!
  end

  def test_lightweight_snapshot
    snap = HeapScope.snapshot(mode: :lightweight)
    assert snap.id
    assert snap.timestamp
    assert_equal :lightweight, snap.mode
    assert snap.gc_stat.is_a?(Hash)
    assert snap.gc_stat.key?(:heap_live_slots) || snap.gc_stat.key?("heap_live_slots") || !snap.gc_stat.empty?
    assert snap.class_stats.is_a?(Hash)
    refute_empty snap.class_stats
  end

  def test_standard_snapshot_json_roundtrip
    snap = HeapScope.snapshot(mode: :standard)
    path = File.join(Dir.tmpdir, "heapscope-snap-#{Process.pid}.json")
    snap.save(path)
    loaded = HeapScope::Snapshot.load(path)
    assert_equal snap.id, loaded.id
    assert_equal snap.class_count("String"), loaded.class_count("String")
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  def test_rss_tracking_capability
    caps = HeapScope.capabilities
    assert caps.each_object
    assert caps.gc_stat
    assert_includes [true, false], caps.rss_tracking
  end
end
