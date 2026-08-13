# Guide: Production-safe sampling

```ruby
HeapScope.configure do |c|
  c.mode = :production_safe
  c.object_sample_rate = 0.05
end

use HeapScope::Middleware, sample_rate: 0.01, mode: :lightweight
```

Rules of thumb:

- Never force GC in production paths
- Prefer `lightweight` snapshots
- Ship reports to local disk / log drains you already trust — HeapScope itself uploads nothing
- Treat HTML/JSON outputs as sensitive
