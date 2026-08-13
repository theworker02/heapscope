# Contributing to HeapScope

Thanks for helping build retention-first Ruby diagnostics.

## Principles

1. Prefer **retention evidence** over allocation volume alone.
2. Separate **facts**, **derived metrics**, **hypotheses**, and **suspected causes**.
3. Never fabricate reachability roots or confidence percentages.
4. Keep the core dependency set minimal (stdlib + `fiddle`).
5. Optional integrations must not become required gems.
6. Degrade safely when a runtime capability is missing.
7. Treat privacy as a feature: no telemetry, no value dumps by default.

## Setup

```bash
bundle install
bundle exec rake test
bundle exec rubocop
bundle exec ruby benchmark/run.rb
bundle exec ruby benchmark/eval_harness.rb
```

## Project layout

| Path | Purpose |
|------|---------|
| `lib/heapscope/` | Library |
| `lib/heapscope/cli/` | Modular CLI |
| `test/` | Minitest suite |
| `examples/` | Demonstrations (+ README branding) |
| `docs/` | Guides + diagnostic encyclopedia |
| `assets/` | Logos / wordmark (canonical) |
| `site/` | GitHub Pages marketing site |
| `benchmark/` | Overhead + eval harness |

## Pull requests

- Conventional commits: `feat:`, `fix:`, `docs:`, `test:`, `chore:`, `refactor:`
- Update `CHANGELOG.md` under `[Unreleased]`
- Add `docs/changelogs/X.Y.Z.md` when cutting a release
- Add/adjust diagnostic docs when introducing finding codes
- Keep PRs focused

## Branding

Logo sources:

- `assets/logo.svg` — app mark
- `assets/wordmark.svg` — horizontal lockup
- `assets/heapscope-logo.png` — raster

Please don’t introduce purple-glow AI-slop aesthetics; HeapScope’s look is teal/slate, calm, technical.

## Code of conduct

See [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).

## Security

See [`SECURITY.md`](SECURITY.md).

## Release

Semantic versioning. Standard Bundler flow:

```bash
# bump lib/heapscope/version.rb
# update CHANGELOG.md + docs/changelogs/
bundle exec rake release
```
