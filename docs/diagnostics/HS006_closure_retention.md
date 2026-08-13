# HS006 — closure_retention

## What it means

Long-lived `Proc` objects appear to retain large object graphs via captured bindings.

## Evidence used

- Proc population growth
- Approximate retained size from bounded traversal
- Allocation site of the Proc when tracing is enabled

## Caveats

Runtime APIs may not expose closure captures cleanly — treat as hypothesis.
