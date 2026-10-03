# Full Mirror policy map

```mermaid
flowchart TD
  A[Select policy] --> B[Bounded internal full-tree scan]
  B --> C[Read-only preview]
  C --> D[Explicit apply]
  D --> E[STRICT: new, updates, verified deletes]
  D --> F[UPDATE_KEEP_EXTRAS: new and updates]
  D --> G[MISSING_ONLY: publish only if absent]
  E --> H[Keep pending queue]
  F --> H
  G --> H
```

Scans use terminating errors and reject reparse points/type conflicts. They are independent of robocopy output language. Apply creates only planned directories/files; it does not turn a mkdir into an unpreviewed subtree copy. Strict revalidates source absence; missing-only preserves a target created after preview.
