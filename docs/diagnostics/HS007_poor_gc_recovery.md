# HS007 — poor_gc_recovery

## What it means

After opt-in forced GC, live populations or RSS remain elevated versus baseline.

## Evidence used

- Before / after GC / after idle phase snapshots

## False positives

- Native memory / fragmentation (see HS010)
- Intentional caches filled during workload

## Note

Forced GC distorts production behavior — experiments only.
