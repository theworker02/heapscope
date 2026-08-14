<p align="center">
  <img src="assets/wordmark.svg" alt="HeapScope" width="520"/>
</p>

<p align="center">
  <strong>Ruby object retention, heap growth, and memory leak diagnostics</strong><br/>
  <em>Not just “how much memory” — <strong>why</strong> the process is keeping it.</em>
</p>

<p align="center">
  <a href="https://rubygems.org/gems/heapscope"><img alt="Gem version" src="https://img.shields.io/gem/v/heapscope?style=plastic&color=0f766e&label=gem"></a>
  <a href="https://rubygems.org/gems/heapscope"><img alt="RubyGems" src="https://img.shields.io/badge/RubyGems-heapscope-CC342D?style=plastic&logo=ruby&logoColor=white"></a>
  <a href="https://github.com/theworker02/heapscope/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/theworker02/heapscope/ci.yml?branch=main&style=plastic&label=CI"></a>
  <a href="LICENSE"><img alt="MIT" src="https://img.shields.io/badge/license-MIT-334155?style=plastic"></a>
  <a href="#ruby-compatibility"><img alt="Ruby" src="https://img.shields.io/badge/ruby-%3E%3D%203.1-CC342D?style=plastic&logo=ruby&logoColor=white"></a>
  <a href="#privacy"><img alt="Privacy" src="https://img.shields.io/badge/privacy-local%20only-0f766e?style=plastic"></a>
  <a href="#no-saas"><img alt="No SaaS" src="https://img.shields.io/badge/SaaS-none-64748b?style=plastic"></a>
  <a href="https://thanks.dev/u/gh/theworker02"><img alt="thanks.dev" src="https://img.shields.io/badge/thanks.dev-theworker02-0f766e?style=plastic"></a>
  <a href="https://theworker02.github.io/heapscope/"><img alt="Docs" src="https://img.shields.io/badge/docs-Pages-0f766e?style=plastic"></a>
  <a href="CHANGELOG.md"><img alt="Changelog" src="https://img.shields.io/badge/changelog-keep%20a%20changelog-0f766e?style=plastic"></a>
</p>

<p align="center">
  <a href="https://rubygems.org/gems/heapscope"><strong>RubyGems</strong></a> ·
  <a href="https://theworker02.github.io/heapscope/">Website</a> ·
  <a href="docs/index.md">Docs hub</a> ·
  <a href="#quick-start">Quick start</a> ·
  <a href="docs/cli.md">CLI</a> ·
  <a href="#privacy">Privacy</a> ·
  <a href="https://github.com/sponsors/theworker02">GitHub Sponsors</a> ·
  <a href="https://thanks.dev/u/gh/theworker02">thanks.dev</a> ·
  <a href="CHANGELOG.md">Changelog</a> ·
  <a href="https://github.com/theworker02/heapscope/releases/tag/v0.7.0">Release notes</a>
</p>

---

## What HeapScope is

**HeapScope** is a local, evidence-driven Ruby gem for diagnosing **object retention**,
**abnormal heap growth**, **allocation hot spots**, **long-lived objects**, and
**leak-shaped patterns** in long-running processes.

It is designed for Rails, Puma, Sidekiq, background jobs, CLIs, and CI — distinguishing
allocation pressure from retention, and intentional caches from suspicious growth.

> **No SaaS.** No uploads. No telemetry. Everything runs in-process on your machine.

| | |
|--|--|
| **Install (gem)** | [rubygems.org/gems/heapscope](https://rubygems.org/gems/heapscope) · `gem install heapscope` |
| **Site / docs** | [theworker02.github.io/heapscope](https://theworker02.github.io/heapscope/) |
| **Source** | [github.com/theworker02/heapscope](https://github.com/theworker02/heapscope) |
| **Changelog** | [`CHANGELOG.md`](CHANGELOG.md) · [narrative 0.7.0](docs/changelogs/0.7.0.md) |
| **Release notes** | [GitHub v0.7.0](https://github.com/theworker02/heapscope/releases/tag/v0.7.0) |
| **Sponsor** | [GitHub Sponsors](https://github.com/sponsors/theworker02) · [thanks.dev](https://thanks.dev/u/gh/theworker02) |

---

## Why HeapScope

Traditional tools often answer: *“How much memory is the process using?”*

HeapScope answers: *“Why is this Ruby process retaining more memory than expected?”*

Every finding separates **observed facts**, **derived behavior**, **hypothesis**, and
**suspected cause** — and never claims `"Memory leak confirmed"` without strong evidence.

---

## Installation

Install from [RubyGems](https://rubygems.org/gems/heapscope) (MRI Ruby ≥ 3.1 recommended):

```bash
gem install heapscope
```

Or add to your Gemfile:

```ruby
# Gemfile
gem "heapscope", "~> 0.7"
```

```bash
bundle add heapscope
```

Confirm the install:

```bash
heapscope about
heapscope doctor
```

From source (development / contributing):

```bash
git clone https://github.com/theworker02/heapscope.git
cd heapscope
bundle install
bundle exec rake test
```

Release notes and source tags: [GitHub Releases](https://github.com/theworker02/heapscope/releases) · narrative: [`docs/changelogs/0.7.0.md`](docs/changelogs/0.7.0.md)

---

## Ruby compatibility

| Engine | Status |
|--------|--------|
| **MRI Ruby ≥ 3.1** | Primary target — full ObjectSpace / allocation tracing / memsize |
| JRuby | Adapter present; capabilities degrade safely |
| TruffleRuby | Adapter present; capabilities degrade safely |

```ruby
puts HeapScope.capabilities
```

---

## Quick start

```ruby
require "heapscope"

report = HeapScope.measure(force_gc: true) { perform_work }
puts report
report.save("report.json")
report.save_html("report.html")

# Ranked follow-ups
puts HeapScope.next_steps(report)

# CI gate
budget = HeapScope.budget_preset(:ci_strict)
HeapScope.check(budget: budget) { perform_work }
```

```bash
heapscope doctor --fix          # write starter heapscope.yml
heapscope snapshot --slim -o before.json
heapscope diff before.json after.json --html report.html --fail-on-medium
heapscope suggest report.json    # next steps + ignore hints
heapscope watch --duration 120 -o watch.json
heapscope about
```

Full CLI: [docs/cli.md](docs/cli.md)

---

## Product surface

| Capability | How |
|------------|-----|
| Snapshots (lightweight / standard / deep / slim JSON) | `HeapScope.snapshot` / `heapscope snapshot` |
| Diff & compare | `HeapScope.compare` / `heapscope diff` |
| Block measure & multi-cycle retention | `measure` / `retention_test` |
| Ranked findings + next steps | analyzer + `Suggest` |
| Budget presets | `Budget.preset(:rails_request\|:sidekiq_job\|:ci_strict)` |
| Sessions & scorecards | `HeapScope.session` / `probe` |
| Watch / monitor with alerts | `heapscope watch` / `Monitor` |
| Report packs | `HeapScope.pack` / `heapscope pack` |
| Baselines & schema validation | `baseline` / `validate` |
| Rails / Rack / Sidekiq / RSpec / Minitest | optional require paths |

---

## Concepts

### Ruby heap vs RSS

HeapScope records **both** Ruby heap populations and process RSS.
**RSS growth ≠ Ruby object leak** — native extensions, allocators, mmap, and CoW matter.

### Allocated vs retained

```text
100,000 allocated + 99,500 freed  → churn
100,000 allocated + 20,000 live   → retention
```

### Forced GC

Opt-in only (`force_gc: true`). Never enabled by surprise; refuse deep walks in `production_safe`.

---

## Budgets & CI

```ruby
HeapScope::Budget.preset(:rails_request)
HeapScope::Budget.preset(:sidekiq_job)
HeapScope::Budget.preset(:ci_strict)

# or hand-tuned
HeapScope::Budget.new(
  max_retained_objects: 1_000,
  max_rss_growth: 30 * 1024 * 1024,
  severity_threshold: :high
)
```

```bash
heapscope baseline create report.json -o baseline.json
heapscope compare baseline.json current.json --threshold 0.5
```

Guide: [docs/guides/ci-budgets.md](docs/guides/ci-budgets.md)

---

## Monitoring

```ruby
monitor = HeapScope::Monitor.start(interval: 10, mode: :lightweight, alert: true)
# ...
report = monitor.stop
```

```bash
heapscope watch --interval 10 --duration 600 -o monitor.json
heapscope flamegraph snapshot.json --format speedscope -o alloc.json
```

`heapscope flamegraph` turns captured allocation sites into folded stacks (inferno / flamegraph.pl) or Speedscope JSON. Capture with `--track-allocations` (or `mode: :deep`) so sites are present.

Alerts fire on RSS / live-slot spikes between samples (thresholds configurable).

---

## Diagnostics

| Code | Name |
|------|------|
| HS001 | persistent_class_growth |
| HS002 | high_retention_ratio |
| HS003 | thread_local_retention |
| HS004 | unbounded_collection |
| HS005 | callback_accumulation |
| HS006 | closure_retention |
| HS007 | poor_gc_recovery |
| HS008 | baseline_regression |
| HS009 | high_allocation_pressure |
| HS010 | native_memory_mismatch |

```bash
heapscope codes
heapscope explain HS001
```

Encyclopedia: [`docs/diagnostics/`](docs/diagnostics/)

---

## Configuration

```ruby
HeapScope.configure do |config|
  config.mode = :standard # lightweight | standard | deep | production_safe | development
  config.track_allocations = false
  config.ignore_patterns << /Zeitwerk/
  config.inspect_values = false # privacy: off by default
end
```

```bash
heapscope doctor --fix --config-out heapscope.yml
heapscope --config heapscope.yml doctor
```

Branding / funding URLs live in `HeapScope::Branding` (single source of truth).

---

## Reports

Text, Markdown, versioned JSON, and static HTML — all offline. HTML uses the same brand mark as the site and README. Reports include **NEXT STEPS** when findings warrant follow-up.

```ruby
HeapScope.pack(report, "./pack")
```

---

## Integrations

```ruby
require "heapscope/middleware"       # Rack sample_rate
require "heapscope/rails"            # request_retention helpers
require "heapscope/sidekiq_middleware"
require "heapscope/minitest"
require "heapscope/rspec"
```

Core gem requires **stdlib only** (plus `fiddle` when available for Windows RSS).

---

## Privacy

<a id="privacy"></a>
<a id="no-saas"></a>

By default HeapScope:

- makes **no network calls**
- sends **no telemetry / analytics**
- does **not** serialize object values
- does **not** dump ENV, tokens, cookies, or request bodies

See [`SECURITY.md`](SECURITY.md).

---

## Examples

```bash
bundle exec ruby examples/healthy_churn.rb
bundle exec ruby examples/import_leak.rb
bundle exec ruby examples/showcase.rb
```

See [`examples/README.md`](examples/README.md).

---

## Architecture

```text
lib/heapscope.rb                 Public API
lib/heapscope/runtime/*          Engine adapters + RSS
lib/heapscope/collector.rb       Snapshot capture
lib/heapscope/diff.rb            Population diffs
lib/heapscope/analyzer.rb        Findings & suspects
lib/heapscope/findings.rb        Codes + ranking/dedupe
lib/heapscope/suggest.rb         Next steps + ignore hints
lib/heapscope/budget.rb          CI budgets + presets
lib/heapscope/scorecard.rb       Probe + executive scorecard
lib/heapscope/session.rb         Named artifact sessions
lib/heapscope/report/*           Text / HTML / Markdown
lib/heapscope/cli/               Modular CLI commands
```

---

## Roadmap

See [`docs/ROADMAP.md`](docs/ROADMAP.md). Current focus: deeper precision and optional CI marketplace packaging — not parallel product surfaces.

---

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) and [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).

```bash
bundle install
bundle exec rake test
bundle exec rubocop
gem build heapscope.gemspec
```

---

## License

MIT © [@theworker02](https://github.com/theworker02) — see [`LICENSE`](LICENSE).

Sponsor: [GitHub Sponsors](https://github.com/sponsors/theworker02) · [thanks.dev/u/gh/theworker02](https://thanks.dev/u/gh/theworker02)

---

<p align="center">
  <img src="assets/logo.svg" alt="" width="72"/><br/>
  <sub>When <code>top</code> says memory is growing but profiling won’t say why — reach for HeapScope.</sub>
</p>
