# Guide: CI memory budgets

## Presets (0.6+)

```ruby
HeapScope.budget_preset(:rails_request)  # typical request cycle
HeapScope.budget_preset(:sidekiq_job)    # background job
HeapScope.budget_preset(:ci_strict)      # tight PR gate
```

```ruby
report = HeapScope.check_budget(budget: HeapScope.budget_preset(:ci_strict)) { scenario }
raise report.budget_result[:violations].join("\n") unless report.passed_budget?
```

## Capture a baseline on `main`

```bash
bundle exec ruby script/memory_scenario.rb # writes report.json
heapscope baseline create report.json -o baseline.json
git add baseline.json
```

## On PRs

```bash
heapscope compare baseline.json report.json --threshold 0.5
```

Exit code `1` means regression.

## Hand-tuned budgets

```ruby
budget = HeapScope::Budget.new(
  max_retained_objects: 2_000,
  max_rss_growth: 20 * 1024 * 1024,
  severity_threshold: :high
)
report = HeapScope.check_budget(budget: budget) { scenario }
```

Keep thresholds noisy-tolerant; prefer `experiment(runs: 5)` medians for flaky heaps.
