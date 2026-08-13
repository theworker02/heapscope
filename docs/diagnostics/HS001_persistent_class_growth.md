# HS001 — persistent_class_growth

## What it means

A class's live object count increased across the measured window or retention cycles.

## Evidence used

- Class counts before/after (or multi-sample series)
- Growth pattern (`monotonic_growth`, `linear_growth`, `exponential_like`)
- Optional forced-GC between samples

## Likely causes

- Unbounded registry / array / hash
- Request or job objects retained globally or in thread-locals
- Memoization without eviction
- Callbacks retaining contexts

## False positives

- Cache warmup / lazy loading
- First-time autoload in development
- Batch size increases that are intentional
- Delayed GC (mitigate with `force_gc: true` in experiments)

## How to investigate

1. Run `HeapScope.retention_test` with forced GC
2. Enable allocation tracing for the class's sites
3. Inspect thread-locals, globals, and constants
4. Use deep mode retention paths for sampled objects

## Potential fixes

- Clear request/job context in `ensure`
- Bound caches / use TTL or LRU
- Unsubscribe listeners
- Avoid capturing large objects in long-lived closures
