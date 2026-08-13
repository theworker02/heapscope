# frozen_string_literal: true

require_relative "test_helper"

class ProfessionalFeaturesTest < Minitest::Test
  def setup
    HeapScope.reset_config!
  end

  def test_probe_scorecard
    result = HeapScope.probe(title: "unit-probe", print: false, force_gc: true, mode: :lightweight) do
      arr = []
      200.times { arr << Object.new }
      arr
    end
    assert result.report
    assert_equal "unit-probe", result.scorecard.title
    assert result.scorecard.to_text.include?("Verdict")
  end

  def test_session_persists_report
    Dir.mktmpdir do |dir|
      session = HeapScope.session("ci-demo", root: dir)
      report = HeapScope.measure(force_gc: true, mode: :lightweight) { 10.times { Object.new } }
      entry = session.record(report, label: "first")
      assert File.exist?(entry[:path])
      assert File.exist?(entry[:html])
      listed = HeapScope::Session.list(root: dir)
      assert listed.any? { |s| s[:name] == "ci-demo" }
    end
  end

  def test_tables_ascii_and_markdown
    before = HeapScope.snapshot(mode: :lightweight)
    after = HeapScope.snapshot(mode: :lightweight)
    diff = HeapScope::Diff.new(before, after)
    ascii = diff.to_table(format: :ascii)
    md = diff.to_table(format: :markdown)
    assert_match(/\+-/, ascii)
    assert_match(/\| CLASS/, md)
  end

  def test_schema_validation
    report = HeapScope.compare(
      HeapScope.snapshot(mode: :lightweight),
      HeapScope.snapshot(mode: :lightweight)
    )
    Dir.mktmpdir do |dir|
      path = File.join(dir, "r.json")
      report.save(path)
      assert HeapScope::Schema.valid?(JSON.parse(File.read(path), symbolize_names: true))
      assert_raises(HeapScope::InvalidReportError) do
        HeapScope::Schema.validate!({ hello: "world" })
      end
    end
  end

  def test_catalog_codes
    text = HeapScope::Catalog.to_text
    assert_match(/HS001/, text)
    assert_equal 10, HeapScope.codes.size
  end

  def test_report_helpers
    report = HeapScope.compare(
      HeapScope.snapshot(mode: :lightweight),
      HeapScope.snapshot(mode: :lightweight)
    )
    assert report.scorecard.verdict
    assert report.table.is_a?(String)
    assert report.findings_table.is_a?(String)
  end

  def test_cli_codes_and_validate
    code = nil
    out = capture_io { code = HeapScope::CLI.new.run(["codes"]) }.first
    assert_equal 0, code
    assert_match(/HS003/, out)

    Dir.mktmpdir do |dir|
      path = File.join(dir, "ok.json")
      HeapScope.compare(
        HeapScope.snapshot(mode: :lightweight),
        HeapScope.snapshot(mode: :lightweight)
      ).save(path)
      code2 = nil
      out2 = capture_io { code2 = HeapScope::CLI.new.run(["validate", path]) }.first
      assert_equal 0, code2
      assert_match(/OK/, out2)
    end
  end
end
