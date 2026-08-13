# API overview

Public entry points (see also the README and [`docs/index.md`](../index.md)):

```ruby
HeapScope.snapshot
HeapScope.compare(before, after)
HeapScope.measure(...) { }
HeapScope.retention_test(...) { }
HeapScope.experiment(...) { }
HeapScope.repeat(n) { }
HeapScope.probe(title: "…") { }       # scorecard + report
HeapScope.session("name")             # .heapscope/sessions persistence
HeapScope.scorecard(report)
HeapScope.check_budget(budget:) { }
HeapScope.check(budget:) { }          # raises BudgetExceededError
HeapScope.capabilities
HeapScope.doctor
HeapScope.overhead(mode: :lightweight)
HeapScope.codes
HeapScope.about
HeapScope.branding
HeapScope.suggest_ignores(report)
HeapScope.next_steps(report)
HeapScope.budget_preset(:ci_strict)
HeapScope.pack(report, "./out")
HeapScope.write_config!("heapscope.yml")
HeapScope.load_config!("heapscope.yml")
HeapScope.configure { |c| }
HeapScope.ignore_class(MyCache)
HeapScope.after_warmup { }
```

Key types:

| Class / module | Role |
|----------------|------|
| `Snapshot` | Point-in-time heap summary (`save(slim: true)`) |
| `Diff` | Before/after comparison (+ `to_table`) |
| `Report` | Findings + presentation (+ `scorecard`, `table`, `next_steps`) |
| `Scorecard` / `Probe` | Executive verdict / one-shot measure |
| `Session` | Named artifact folders |
| `Finding` / `Findings` | Evidence-structured diagnostic + ranking |
| `Budget` | CI gates + presets |
| `Suggest` | Next steps + ignore hints |
| `Monitor` | Sampling + optional anomaly alerts |
| `Branding` | URLs, banners, asset paths |
| `Budget` | CI thresholds |
| `Monitor` | Interval sampler |
| `TrendStore` | Historical samples |
| `RetentionSession` | Multi-cycle tracker |
| `Graph` | Bounded reachability |
| `Detectors` | Thread-local / collection classifiers |
| `Schema` | Report JSON validation |
| `Catalog` | HS001–HS010 catalog |
| `Branding` | Banner, funding, footers |
| `Suggest` | Ignore-pattern recommendations |
| `Pack` | Local report export bundles |
| `Tables` | ASCII / Markdown tables |

Optional requires:

```ruby
require "heapscope/cli"
require "heapscope/middleware"
require "heapscope/rails"
require "heapscope/sidekiq_middleware"
require "heapscope/rspec"
require "heapscope/minitest"
```
