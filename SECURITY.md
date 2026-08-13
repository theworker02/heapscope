# Security Policy

## Privacy posture

HeapScope is a **local** diagnostics toolkit.

- No network calls in normal operation
- No telemetry, analytics, or automatic uploads
- No serialization of object values by default
- No dumping of `ENV`, credentials, tokens, cookies, or request bodies by default

Memory inspection is inherently sensitive. Treat snapshots and reports as **confidential** if they were captured in environments that handle personal or secret data — even when values are redacted, class names and allocation sites can still leak product structure.

## Supported versions

| Version | Supported |
|---------|-----------|
| 0.6.x | ✅ |
| 0.5.x | ✅ |
| 0.4.x | ✅ (security fixes when practical) |
| < 0.4 | ❌ |

## Reporting a vulnerability

Please open a GitHub Security Advisory or email the maintainers privately. Do **not** file a public issue that includes exploit details for unreleased flaws.

We aim to acknowledge reports within 7 days.

## Safe production use

Prefer:

```ruby
HeapScope.configure do |config|
  config.mode = :production_safe
end
```

Avoid deep heap walks, forced GC, and value inspection on multi-tenant production hosts unless you fully understand the pause and privacy impact.
