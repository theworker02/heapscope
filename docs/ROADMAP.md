# HeapScope roadmap

## Current product (0.6)

One coherent retention diagnostics toolkit: snapshots, diffs, multi-cycle experiments,
ranked findings with next steps, budget presets, slim captures, watch alerts, sessions,
report packs, and a modular CLI — all local-only.

## Shipped history

| Version | Theme |
|---------|--------|
| 0.1–0.3 | Core toolkit, detectors, aging/closures/dominators |
| 0.4 | Sessions, scorecards, schema, GitHub polish |
| 0.5 | Funding, Pages site, pack/suggest, CLI expansion |
| **0.6** | Product consolidation — presets, ranking, watch, slim JSON, doctor --fix |

## Next

- Higher-fidelity dominators when runtime APIs allow
- Packaged GitHub Action for baseline compare
- Async/fiber-heavy runtime playbooks
- Optional heap-dump importers

## Non-goals

- SaaS APM
- “Confirmed leak” from noisy samples
- Secret dumping / telemetry
