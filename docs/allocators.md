# Allocator awareness

HeapScope reports Ruby heap and RSS separately on purpose.

| Allocator | Notes |
|-----------|--------|
| glibc malloc | Can retain free arenas; RSS may not fall after Ruby GC |
| jemalloc | Often smoother; still not equal to Ruby heap size |
| macOS allocator | Zone behavior can obscure release timing |

Fragmentation indicators (RSS vs heap pages vs live/free slots) are reported **conservatively** as potential fragmentation — never "confirmed fragmentation."

Copy-on-write after fork (Puma workers, prefork) can also change RSS without new Ruby object retention.
