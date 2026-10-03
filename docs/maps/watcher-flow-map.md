# Watcher flow map

```mermaid
flowchart TD
  A[Start-Watcher] --> B[Queue-specific watcher mutex]
  B --> C[Validate pairs and register filesystem events]
  C --> D[Created or Changed: Upsert]
  C --> E[Deleted: Delete]
  C --> F[Renamed: old Delete and new Upsert]
  C --> X[Error: log overflow and request manual Full Mirror recovery]
  D --> G[Debounce / directory snapshot]
  E --> G
  F --> G
  G --> H[Mutex-protected commit]
  S[Graceful stop request] --> I[Drain events and flush pending]
  I --> J[Dispose watchers and mutex]
```

The watcher never applies destination changes. Reconciled directory batches compare parent IDs. A forced crash can lose debounced memory; Full Mirror preview is the recovery workflow.
