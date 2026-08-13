# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "tmpdir"

class CliExpansiveTest < Minitest::Test
  def setup
    HeapScope.reset_config!
  end

  def test_help_command_and_subcommand
    code = nil
    out = capture_io { code = HeapScope::CLI.new.run(["help"]) }.first
    assert_equal 0, code
    assert_match(/probe/, out)
    assert_match(/Exit codes/, out)

    out2 = capture_io { code = HeapScope::CLI.new.run(%w[help probe]) }.first
    assert_equal 0, code
    assert_match(/--file/, out2)

    out3 = capture_io { code = HeapScope::CLI.new.run(["probe", "--help"]) }.first
    assert_equal 0, code
    assert_match(/probe/, out3)
  end

  def test_global_quiet_and_json_about
    code = nil
    out = capture_io { code = HeapScope::CLI.new.run(["--json", "about"]) }.first
    assert_equal 0, code
    data = JSON.parse(out)
    assert_equal "theworker02", data["github_user"]
    assert_equal "u/gh/theworker02", data["thanks_dev_path"]
  end

  def test_explain_and_env_and_completion
    code = nil
    out = capture_io { code = HeapScope::CLI.new.run(%w[explain HS001]) }.first
    assert_equal 0, code
    assert_match(/persistent_class_growth|HS001/, out)

    out2 = capture_io { code = HeapScope::CLI.new.run(["env"]) }.first
    assert_equal 0, code
    assert_match(/RUBY_VERSION|NO_COLOR|HeapScope/, out2)

    out3 = capture_io { code = HeapScope::CLI.new.run(%w[completion bash]) }.first
    assert_equal 0, code
    assert_match(/complete -F _heapscope/, out3)

    out4 = capture_io { code = HeapScope::CLI.new.run(%w[completion powershell]) }.first
    assert_equal 0, code
    assert_match(/Register-ArgumentCompleter/, out4)
  end

  def test_probe_eval_and_scorecard_findings_table
    Dir.mktmpdir do |dir|
      report_path = File.join(dir, "probe.json")
      code = nil
      capture_io do
        code = HeapScope::CLI.new.run([
                                        "probe",
                                        "--eval", "200.times { Object.new }",
                                        "--title", "cli-probe",
                                        "-o", report_path,
                                        "--no-force-gc"
                                      ])
      end
      assert_equal 0, code
      assert File.exist?(report_path)

      out = capture_io { code = HeapScope::CLI.new.run(["scorecard", report_path]) }.first
      assert_equal 0, code
      assert_match(/scorecard|Verdict/i, out)

      out2 = capture_io { code = HeapScope::CLI.new.run(["findings", report_path, "--json"]) }.first
      assert_equal 0, code
      payload = JSON.parse(out2)
      assert payload.key?("findings")

      out3 = capture_io { code = HeapScope::CLI.new.run(["table", report_path]) }.first
      assert_equal 0, code
      assert_match(/CLASS|BEFORE|AFTER|\+/, out3)
    end
  end

  def test_open_html_and_export_alias
    Dir.mktmpdir do |dir|
      before = HeapScope.snapshot(mode: :lightweight)
      after = HeapScope.snapshot(mode: :lightweight)
      report = HeapScope.compare(before, after)
      path = File.join(dir, "r.json")
      report.save(path)

      code = nil
      out = capture_io { code = HeapScope::CLI.new.run(["open", path]) }.first
      assert_equal 0, code
      html_path = out.strip
      assert File.exist?(html_path)
      assert_match(/\.html\z/, html_path)

      pack_dir = File.join(dir, "bundle")
      out2 = capture_io { code = HeapScope::CLI.new.run(["export", path, "-o", pack_dir]) }.first
      assert_equal 0, code
      assert_match(/Wrote local pack/, out2)
      assert File.directory?(pack_dir)
    end
  end

  def test_self_test_and_man
    code = nil
    out = capture_io { code = HeapScope::CLI.new.run(["self-test", "--json"]) }.first
    assert_equal 0, code
    data = JSON.parse(out)
    assert data["scorecard"]
    assert data["note"]

    out2 = capture_io { code = HeapScope::CLI.new.run(["man"]) }.first
    assert_equal 0, code
    assert_match(/Examples/, out2)
    assert_match(%r{thanks\.dev/u/gh/theworker02}, out2)
  end

  def test_catalog_explain_unknown
    assert_raises(ArgumentError) { HeapScope::Catalog.explain("HS999") }
    assert_equal "HS002", HeapScope::Catalog.normalize_code("2")
  end

  def test_diff_fail_on_medium_option_parses
    Dir.mktmpdir do |dir|
      leak = []
      b = HeapScope.snapshot(mode: :lightweight)
      300.times { leak << Object.new }
      a = HeapScope.snapshot(mode: :lightweight)
      bp = File.join(dir, "b.json")
      ap = File.join(dir, "a.json")
      b.save(bp)
      a.save(ap)

      code = nil
      capture_io do
        code = HeapScope::CLI.new.run(["diff", bp, ap, "--scorecard-only", "--fail-on-high"])
      end
      assert_includes [0, 1], code
    end
  end

  def test_ignore_suggest_alias
    Dir.mktmpdir do |dir|
      report = HeapScope.compare(
        HeapScope.snapshot(mode: :lightweight),
        HeapScope.snapshot(mode: :lightweight)
      )
      path = File.join(dir, "r.json")
      report.save(path)
      code = nil
      out = capture_io { code = HeapScope::CLI.new.run(["ignore-suggest", path]) }.first
      assert_equal 0, code
      assert_match(/ignore|pattern|Suggest|review/i, out)
    end
  end
end
