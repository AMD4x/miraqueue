# Queue lifecycle map

```mermaid
flowchart TD
  A[Source event] --> B[Exclusions and safe relative path]
  B --> C[Debounce and indexed reduction]
  C --> D[Queue mutex]
  D --> E[Atomic NDJSON replacement]
  E --> F[Rebuildable schema-2 metadata]
  E --> G[Read-only session snapshot]
  G --> H[Preview]
  H --> I[Explicit apply and fresh reconciliation]
  I --> J[Acknowledge matching successful IDs under mutex]
  J --> E
```

V1 entries normalize under lock, preserving IDs and effective work. Unknown/malformed records stop the entire read. Destination observations remain in process memory. Newer events survive classification and acknowledgment. Full Mirror never empties this queue.
