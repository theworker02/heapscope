# ADR 0002 — Local-only privacy by default

## Status

Accepted

## Context

Heap contents may include credentials, PII, and request payloads.

## Decision

- No network / telemetry in the gem
- No object value serialization by default
- Explicit opt-in + redaction hooks for value inspection

## Consequences

HeapScope cannot offer hosted dashboards without a separate product decision. Privacy becomes a marketable feature.
