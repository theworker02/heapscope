# Guide: First retention experiment

Goal: prove whether a workload **retains** objects across GC, not merely allocates.

## Steps

1. Warm up the app (routes, autoload, DB connections).
2. Capture a baseline mental model: what *should* survive?
3. Run:

```ruby
report = HeapScope.retention_test(cycles: 10, force_gc: true) do
  50.times { MyEndpoint.call }
end
puts report
report.save_html("retention.html")
```

4. Read findings in order: facts → derived → hypothesis → suspected cause.
5. If HS001/HS002 fire, enable allocation tracing and re-run once.
6. Inspect thread-locals if HS003 appears.

## Interpreting HEALTHY

Temporary growth that reclaims after forced GC is success. Do not chase HS009 (churn) as a leak.
