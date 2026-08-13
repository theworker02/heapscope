# ADR 0001 — Evidence over certainty

## Status

Accepted

## Context

Memory tools often collapse observations into “leak detected,” which trains developers to distrust the tool when false positives appear.

## Decision

Every HeapScope finding MUST separate:

1. Observed facts
2. Derived behavior
3. Hypothesis
4. Suspected cause (optional, evidence-gated)

Prefer severity categories (LOW/MEDIUM/HIGH) over unexplained confidence percentages.

## Consequences

Reports are longer and more careful. Users get fewer dramatic claims and more actionable investigation steps.
