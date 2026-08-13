# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Detailed release write-ups live in [`docs/changelogs/`](docs/changelogs/).

## [Unreleased]

## [0.6.0] — 2026-08-13

### Added

- Budget presets: `rails_request`, `sidekiq_job`, `ci_strict` (`Budget.preset` / `HeapScope.budget_preset`)
- Finding priority ranking + dedupe (`Findings.rank_and_dedupe`, `Finding#priority`)
- Next-steps recommendations (`Suggest.next_steps`, `HeapScope.next_steps`, report sections)
- `heapscope watch` — monitor with anomaly alerts (RSS / live-slot spikes)
- Monitor `--alert` / `--rss-alert-bytes` / `--live-alert-slots`
- Slim snapshot JSON (`Snapshot#save(..., slim: true)`, `heapscope snapshot --slim`)
- `heapscope doctor --fix` + `--config-out` — write starter `heapscope.yml`
- `HeapScope.write_config!` / `ConfigLoader.write_starter!`
- Branding asset path helpers (`LOGO_SVG`, `WORDMARK_SVG`, `logo_svg_inline`)
- Examples package README with logo/wordmark
- Rake `docs:codes` task for diagnostic catalog generation

### Changed

- Version **0.6.0** — cohesive professional product release
- `Probe` / `Scorecard` extracted from `session.rb` into `scorecard.rb`
- `ConfigLoader` moved from `noise.rb` into `config.rb`
- Framework ignore hints owned by `Noise::FRAMEWORK_HINTS` (Suggest reuses them)
- Analyzer / retention reports apply ranked, deduped findings
- CLI `suggest` prints next steps + ignore patterns; `--ignores-only` / JSON payload expanded
- HTML reports prefer packaged logo SVG when available; include Next steps
- README / docs / roadmap present a single current-product story (not stacked milestones)
- Supported versions table updated for 0.6.x

## [0.5.0] — 2026-08-13

### Added

- `.github/FUNDING.yml` with GitHub Sponsors (`theworker02`) and thanks.dev (`u/gh/theworker02`)
- GitHub Pages site under `site/` + `pages.yml` deploy workflow
- `HeapScope::Branding` — banner, funding URLs, report footers, `HeapScope.about` / `.branding`
- `HeapScope::Suggest` + `heapscope suggest` — recommended ignore patterns (never auto-applied)
- `HeapScope::Pack` + `heapscope pack` — local JSON+HTML+Markdown report bundles
- CLI `about` command; doctor/help/report footers include funding + docs links
- Gem metadata `funding_uri` / Pages `documentation_uri`
- Expansive CLI UX: global `--verbose` / `--quiet` / `--config` / `--json` / `--color` / `--no-color`
- Per-command help; modular CLI under `lib/heapscope/cli/`
- CLI commands: `probe`, `measure`, `retention`, `findings`, `scorecard`, `table`, `explain`,
  `open`/`html`, `self-test`, `env`, `completion`, `man`; aliases `export`, `ignore-suggest`
- `Catalog.explain` / `Catalog.lookup` for diagnostic encyclopedia entries

### Changed

- Version **0.5.0**
- Homepage / source URIs → `https://github.com/theworker02/heapscope`
- `Catalog` extracted from `session.rb` into `catalog.rb`
- Suggest reuses `Noise` defaults instead of duplicating framework regexes

## [0.4.0] — 2026-08-13

Sessions, scorecards, schema validation, diagnostic catalog, GitHub templates.

## [0.3.0] — 2026-08-12

Aging, globals, closures, fibers, dominators, trends, doctor.

## [0.2.0] — 2026-08-12

Branding, detectors, richer HTML, eval harness, security/CoC.

## [0.1.0] — 2026-08-12

Initial retention toolkit.

[Unreleased]: https://github.com/theworker02/heapscope/compare/v0.6.0...HEAD
[0.6.0]: https://github.com/theworker02/heapscope/releases/tag/v0.6.0
[0.5.0]: https://github.com/theworker02/heapscope/releases/tag/v0.5.0
[0.4.0]: https://github.com/theworker02/heapscope/releases/tag/v0.4.0
[0.3.0]: https://github.com/theworker02/heapscope/releases/tag/v0.3.0
[0.2.0]: https://github.com/theworker02/heapscope/releases/tag/v0.2.0
[0.1.0]: https://github.com/theworker02/heapscope/releases/tag/v0.1.0
