# frozen_string_literal: true

require_relative "lib/heapscope/version"

Gem::Specification.new do |spec|
  spec.name = "heapscope"
  spec.version = HeapScope::VERSION
  spec.authors = ["theworker02"]
  spec.email = ["matthewlooney5@gmail.com"]

  spec.summary = "Ruby object retention, heap growth, and memory leak diagnostics"
  spec.description = <<~DESC
    HeapScope is a local, evidence-driven memory diagnostics toolkit for Ruby.
    It helps identify object retention, abnormal heap growth, allocation hot spots,
    long-lived objects, GC-surviving populations, and likely memory leaks in
    long-running Ruby processes — without claiming a leak unless evidence is strong.
  DESC
  spec.homepage = "https://github.com/theworker02/heapscope"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}.git"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["documentation_uri"] = "https://theworker02.github.io/heapscope/"
  spec.metadata["funding_uri"] = "https://thanks.dev/u/gh/theworker02"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.post_install_message = <<~MSG

    HeapScope #{HeapScope::VERSION} installed.
      heapscope doctor
      heapscope about
      gem:     https://rubygems.org/gems/heapscope
      docs:    https://theworker02.github.io/heapscope/
      sponsor: https://thanks.dev/u/gh/theworker02

    Local-only diagnostics. No telemetry. No object-value dumps by default.
  MSG

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.start_with?(*%w[bin/ test/ spec/ features/ .git .github benchmark/ site/]) ||
        f.end_with?(".gem")
    end
  end
  # Ensure packaging works before first commit
  if spec.files.empty?
    spec.files = Dir[
      "lib/**/*",
      "exe/*",
      "assets/**/*",
      "docs/**/*",
      "examples/**/*",
      "LICENSE*",
      "README*",
      "CHANGELOG*",
      "CONTRIBUTING*",
      "CODE_OF_CONDUCT*",
      "SECURITY*",
      "heapscope.gemspec"
    ]
  end
  spec.files.reject! { |f| f.start_with?("site/") }

  spec.bindir = "exe"
  spec.executables = ["heapscope"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "minitest", "~> 5.20"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rubocop", "~> 1.60"
end
