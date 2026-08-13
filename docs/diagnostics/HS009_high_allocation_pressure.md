# HS009 — high_allocation_pressure

## What it means

Many objects were allocated and mostly freed — **churn**, not necessarily a leak.

## Evidence used

- High allocated Δ with high freed Δ / low retention ratio

## Action

Optimize hot allocation sites if GC/CPU time matters; do not treat as retention failure.
