# HS004 — unbounded_collection

## What it means

An Array/Hash/Set-like structure grows across samples without observed shrinkage after GC.

## Evidence used

- Size series across samples
- Owner class when identifiable

## False positives

- Bounded caches still filling toward max
- Warmup periods

## Fixes

Cap size, eviction, periodic compaction, or stop appending.
