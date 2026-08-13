# HS002 — high_retention_ratio

## What it means

A large fraction of objects allocated during the workload remained reachable afterward.

## Evidence used

- `total_allocated_objects` / `total_freed_objects` deltas
- Surviving estimate and retention ratio

## Likely causes

- Sticky object graphs retained by roots
- Accidental global retention of request data

## False positives

- Workload that intentionally builds long-lived structures
- Insufficient GC between measurements

## Investigation / fixes

Use class deltas + retention sessions; clear accidental roots; bound collections.
