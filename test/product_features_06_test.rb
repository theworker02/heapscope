# frozen_string_literal: true

require_relative "test_helper"

class ProductFeatures06Test < Minitest::Test
  def setup
    HeapScope.reset_config!
  end

  def test_current_product_version
    assert_equal "0.7.0", HeapScope::VERSION
  end

  def test_budget_presets
    assert_equal %i[rails_request sidekiq_job ci_strict], HeapScope::Budget.presets
    budget = HeapScope.budget_preset(:ci_strict)
    assert_equal :ci_strict, budget.preset_name
    assert_equal 500, budget.max_retained_objects
    assert_equal :medium, budget.severity_threshold

    report = HeapScope.compare(
      HeapScope.snapshot(mode: :lightweight),
      HeapScope.snapshot(mode: :lightweight)
    )
    result = budget.evaluate(report)
    assert result.key?(:passed)
    assert_equal :ci_strict, result[:preset]
  end

  def test_findings_rank_and_dedupe
    a = HeapScope::Finding.new(code: "HS001", severity: :low, subject: "Foo")
    b = HeapScope::Finding.new(code: "HS001", severity: :high, subject: "Foo")
    c = HeapScope::Finding.new(code: "HS009", severity: :low, subject: nil)
    ranked = HeapScope::Findings.rank_and_dedupe([a, b, c])
    assert_equal 2, ranked.size
    assert_equal :high, ranked.first.severity
    assert_equal "HS001", ranked.first.code
    assert ranked.first.priority > ranked.last.priority
  end

  def test_next_steps_and_suggest
    leak = []
    report = HeapScope.retention_test(cycles: 3, force_gc: true, mode: :lightweight) do
      80.times { leak << ("x" * 64) }
    end
    steps = HeapScope.next_steps(report)
    assert_kind_of Array, steps
    text = HeapScope::Suggest.report_text(report)
    assert_match(/Next steps/, text)
    assert report.next_steps.is_a?(Array)
  end

  def test_slim_snapshot_json
    snap = HeapScope.snapshot(mode: :lightweight)
    Dir.mktmpdir do |dir|
      full = File.join(dir, "full.json")
      slim = File.join(dir, "slim.json")
      snap.save(full)
      snap.save(slim, slim: true)
      full_data = JSON.parse(File.read(full), symbolize_names: true)
      slim_data = JSON.parse(File.read(slim), symbolize_names: true)
      assert slim_data[:metadata][:slim]
      assert slim_data[:class_stats].size <= HeapScope::Snapshot::SLIM_CLASS_LIMIT
      assert slim_data[:object_sample].empty?
      assert full_data[:class_stats].size >= slim_data[:class_stats].size || full_data[:class_stats].size <= HeapScope::Snapshot::SLIM_CLASS_LIMIT
    end
  end

  def test_monitor_alerts_metadata
    monitor = HeapScope::Monitor.new(
      interval: 60,
      mode: :lightweight,
      alert: true,
      rss_alert_bytes: 1,
      live_alert_slots: 1
    )
    first = HeapScope.snapshot(mode: :lightweight)
    second = HeapScope.snapshot(mode: :lightweight)
    monitor.instance_variable_set(:@samples, [
                                    HeapScope::Monitor::Sample.new(at: Time.now.utc, snapshot: first)
                                  ])
    monitor.send(:maybe_alert!, HeapScope::Monitor::Sample.new(at: Time.now.utc, snapshot: second))
    report = monitor.finish_report
    assert report.metadata[:alerts]
  end

  def test_doctor_fix_writes_config
    Dir.mktmpdir do |dir|
      path = File.join(dir, "heapscope.yml")
      code = nil
      out = capture_io do
        code = HeapScope::CLI.new.run(["doctor", "--fix", "--config-out", path])
      end.first
      assert_equal 0, code
      assert File.exist?(path)
      assert_match(/Wrote starter config/, out)
      assert_match(/Budget presets/, out)
    end
  end

  def test_cli_snapshot_slim
    Dir.mktmpdir do |dir|
      path = File.join(dir, "snap.json")
      code = nil
      capture_io { code = HeapScope::CLI.new.run(["snapshot", "--mode", "lightweight", "--slim", "-o", path]) }
      assert_equal 0, code
      data = JSON.parse(File.read(path), symbolize_names: true)
      assert data[:metadata][:slim]
    end
  end

  def test_branding_asset_constants
    meta = HeapScope.branding
    assert_equal "assets/logo.svg", meta[:logo_svg]
    assert File.file?(HeapScope::Branding.asset_path(HeapScope::Branding::LOGO_SVG))
  end

  def test_scorecard_module_file
    assert defined?(HeapScope::Scorecard)
    assert defined?(HeapScope::Probe)
    assert_equal "0.7.0", HeapScope::Branding.to_h[:version]
  end
end
