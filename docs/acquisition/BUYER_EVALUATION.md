# Buyer evaluation â€” Gemfile

## Goal

In 15â€“45 minutes, verify the Product builds or runs as documented and that proprietary notices are present.

## Steps

1. Confirm root `LICENSE` is proprietary and `ACQUISITION.md` exists.
2. Skim `README.md` install/run claims.
3. Execute:

```
```bash
gem install heapscope
```
```ruby
# Gemfile
gem "heapscope", "~> 0.7"
```
```bash
bundle add heapscope
```
```bash
heapscope about
heapscope doctor
```
```bash
git clone https://github.com/theworker02/heapscope.git
cd heapscope
bundle install
bundle exec rake test
```
```ruby
puts HeapScope.capabilities
```
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
```

4. Run tests if present (`npm test`, `pytest`, `cargo test`, `go test ./...`, etc.).
5. Record README vs observed behavior gaps in workpapers.

## Pass criteria

- [ ] Clone succeeds
- [ ] Documented happy path works **or** failure is explained
- [ ] Minimal path needs no surprise secrets
- [ ] License notices intact

*Updated: 2026-09-22*
