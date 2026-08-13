<p align="center">
  <img src="../assets/wordmark.svg" alt="HeapScope" width="360"/>
</p>

# CLI reference

```bash
heapscope [global options] <command> [options]
```

## Global options

| Flag | Description |
|------|-------------|
| `--verbose` | Verbose HeapScope logging |
| `--quiet` | Suppress non-essential output |
| `--config PATH` | Load YAML/Ruby config before the command |
| `--json` | Prefer machine-readable JSON on key commands |
| `--no-color` / `--color` | Disable or force ANSI colors (also respects `NO_COLOR`) |
| `-h`, `--help` | Show help |
| `-v`, `--version` | Print version |

Per-command help: `heapscope help <command>` or `heapscope <command> --help`.

## Commands

| Command | Description |
|---------|-------------|
| `snapshot` | Capture heap snapshot JSON (`--slim` for compact) |
| `inspect` | Inspect current process or saved capture |
| `diff` | Diff two snapshots (scorecard + table + report) |
| `monitor` | Interval sampling (`--alert` for spikes) |
| `watch` | Monitor with anomaly alerts enabled |
| `trends` | Print monitor timeline |
| `report` | Render text / html / markdown / json |
| `baseline` | Create baseline from report |
| `compare` | Baseline vs current (CI exit codes) |
| `sessions` | List `.heapscope/sessions` |
| `history` | Recent session artifacts |
| `validate` | Validate report schema |
| `suggest` / `ignore-suggest` | Next steps + ignore_patterns (never auto-applied) |
| `pack` / `export` | Export local JSON+HTML+Markdown bundle |
| `probe` | Measure a `--file` / `--eval` workload → scorecard |
| `measure` | CLI wrapper around `HeapScope.measure` |
| `retention` | CLI wrapper around `HeapScope.retention_test` |
| `findings` | List/filter ranked findings |
| `scorecard` | Print scorecard only from a report |
| `table` | Print growth table from a report |
| `explain` | Diagnostic encyclopedia entry |
| `open` / `html` | Write HTML and print path |
| `self-test` | Built-in intentional retention demo |
| `env` | Print relevant environment variables |
| `completion` | Generate bash / zsh / powershell completion |
| `man` | Extended about + examples |
| `codes` | Print HS001–HS010 catalog |
| `doctor` | Runtime + config health (`--fix` writes starter YAML) |
| `overhead` | Snapshot overhead microbench |
| `config` | Load YAML/Ruby config |
| `about` | Branding, docs, and funding links |
| `capabilities` | Capability matrix |
| `version` | Print version |
| `help` | Global or per-command help |

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Regression / finding above threshold (`--fail-on-*`) |
| 2 | Invalid input / configuration |
| 3 | Capability unavailable |

## Notable flags

- `snapshot`: `--slim`, `--mode`, `--force-gc`, `--track-allocations`
- `monitor` / `watch`: `--alert`, `--rss-alert-bytes`, `--live-alert-slots`
- `doctor`: `--fix`, `--config-out PATH`, `--force`
- `suggest`: `--json` (next_steps + ignore_patterns), `--ignores-only`
- Analysis commands: `--fail-on-high`, `--fail-on-medium`, `--fail-on LEVEL`

## Examples

```bash
heapscope about
heapscope doctor --fix
heapscope snapshot --slim -o before.json
heapscope diff before.json after.json --html out.html --fail-on-medium
heapscope watch --duration 120 -o watch.json
heapscope suggest report.json
heapscope pack report.json -o ./pack
heapscope explain HS001
```

Sponsor: https://thanks.dev/u/gh/theworker02 · Site: https://theworker02.github.io/heapscope/ · Gem: https://rubygems.org/gems/heapscope


<p align="center">
  <img src="../assets/logo.svg" alt="" width="48"/>
</p>
