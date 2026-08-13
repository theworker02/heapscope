# ADR 0003 — Runtime adapters (MRI-first)

## Status

Accepted

## Context

ObjectSpace APIs differ across MRI, JRuby, and TruffleRuby.

## Decision

Expose a capability matrix via adapters:

```text
HeapScope::Runtime::MRI
HeapScope::Runtime::JRuby
HeapScope::Runtime::TruffleRuby
```

Never pretend unavailable features exist.

## Consequences

Slightly more code, much safer degradation, and a clear extension point for future engines.
