# HS010 — native_memory_mismatch

## What it means

Process RSS grew substantially while the Ruby heap (live slots / object estimates) did not.

## Evidence used

- RSS Δ vs heap live slots Δ and shallow byte estimates

## Likely causes

- Native extension allocations
- Allocator fragmentation (glibc / jemalloc / macOS)
- mmap / external buffers

## Important

**RSS growth ≠ Ruby object leak.** Do not blame object retention from this signal alone.
