# HS003 — thread_local_retention

## What it means

Retention appears consistent with thread-local (or fiber-local) storage holding growing state — common under Puma/Sidekiq thread reuse.

## Evidence used

- Thread key inventory
- Growing populations reachable from thread contexts
- Persistence across request/job cycles

## Likely causes

- `Thread.current[:context]` not cleared
- Middleware storing request state on the worker thread

## False positives

- Intentional per-thread caches with bounds

## Fixes

Clear thread/fiber locals in `ensure` after each request/job; avoid storing full request graphs.
