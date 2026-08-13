# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "tmpdir"

class CliBaselineTest < Minitest::Test
  def test_cli_version
    code = HeapScope::CLI.new.run(["version"])
    assert_equal 0, code
  end

  def test_cli_capabilities
    require "heapscope/cli"
    out = capture_io { HeapScope::CLI.new.run(["capabilities"]) }.first
    assert_match(/allocation_tracing/, out)
  end

  def test_baseline_compare_regression
    Dir.mktmpdir do |dir|
      leak = []
      report = HeapScope.measure(force_gc: true, mode: :lightweight) do
        50.times { leak << Object.new }
      end
      report_path = File.join(dir, "report.json")
      baseline_path = File.join(dir, "baseline.json")
      report.save(report_path)
      HeapScope::Baseline.create(report_path, baseline_path)

      bigger = HeapScope.measure(force_gc: true, mode: :lightweight) do
        5_000.times { leak << Object.new }
      end
      bigger_path = File.join(dir, "bigger.json")
      bigger.save(bigger_path)

      result = HeapScope::Baseline.compare(baseline_path, bigger_path, threshold: 0.2)
      assert_equal "REGRESSION", result[:result]
      assert result[:findings].any? { |f| f.code == "HS008" }
    end
  end

  def test_text_and_html_report
    before = HeapScope.snapshot(mode: :lightweight)
    after = HeapScope.snapshot(mode: :lightweight)
    report = HeapScope.compare(before, after)
    text = report.to_text
    html = HeapScope::Report::HTML.render(report)
    assert_match(/HEAPSCOPE/, text)
    assert_match(/<html/, html)
  end
end
