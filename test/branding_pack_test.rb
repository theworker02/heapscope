# frozen_string_literal: true

require_relative "test_helper"

class BrandingPackTest < Minitest::Test
  def setup
    HeapScope.reset_config!
  end

  def test_branding_funding_paths
    meta = HeapScope.branding
    assert_equal "theworker02", meta[:github_user]
    assert_equal "u/gh/theworker02", meta[:thanks_dev_path]
    assert_equal "https://thanks.dev/u/gh/theworker02", meta[:thanks_dev_url]
    assert_match(/theworker02\.github\.io/, meta[:pages_url])
    about = HeapScope.about
    assert_match(/thanks\.dev/, about)
    assert_match(/HeapScope/, about)
  end

  def test_cli_about
    code = nil
    out = capture_io { code = HeapScope::CLI.new.run(["about"]) }.first
    assert_equal 0, code
    assert_match(%r{thanks\.dev/u/gh/theworker02}, out)
  end

  def test_suggest_and_pack
    report = HeapScope.compare(
      HeapScope.snapshot(mode: :lightweight),
      HeapScope.snapshot(mode: :lightweight)
    )
    patterns = HeapScope.suggest_ignores(report)
    assert_kind_of Array, patterns

    Dir.mktmpdir do |dir|
      result = HeapScope.pack(report, dir, label: "demo")
      assert File.exist?(result[:json])
      assert File.exist?(result[:html])
      assert File.exist?(result[:markdown])
      assert File.exist?(result[:readme])
      readme = File.read(result[:readme])
      assert_match(%r{thanks\.dev/u/gh/theworker02}, readme)

      code = nil
      out = capture_io { code = HeapScope::CLI.new.run(["pack", result[:json], "-o", File.join(dir, "cli-pack")]) }.first
      assert_equal 0, code
      assert_match(/Wrote local pack/, out)
    end
  end

  def test_catalog_includes_branding
    text = HeapScope::Catalog.to_text
    assert_match(/HS001/, text)
    assert_match(/thanks\.dev/, text)
  end

  def test_report_footer_mentions_funding
    report = HeapScope.compare(
      HeapScope.snapshot(mode: :lightweight),
      HeapScope.snapshot(mode: :lightweight)
    )
    assert_match(%r{thanks\.dev/u/gh/theworker02}, report.to_text)
    assert_match(%r{thanks\.dev/u/gh/theworker02}, report.to_markdown)
    assert_match(%r{thanks\.dev/u/gh/theworker02}, HeapScope::Report::HTML.render(report))
  end
end
