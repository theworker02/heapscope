# HS008 — baseline_regression

## What it means

Current retention exceeds a stored baseline beyond a configured threshold.

## Evidence used

- Baseline retained objects/bytes vs current report

## Use in CI

```bash
heapscope compare baseline.json current.json --threshold 0.5
```
