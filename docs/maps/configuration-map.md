# Configuration map

```mermaid
flowchart TD
  A[Initialize-App] --> B[Load existing JSON or defaults]
  B --> C[Ensure-ConfigShape]
  C --> D[Preserve user settings and add missing defaults]
  D --> E[Validate runtime names and DataDir]
  E --> F[Initialize or read existing storage]
  G[Explicit config edit] --> H[Write-AtomicText]
  H --> I[Invalidate snapshot and refresh watcher]
```

Loading a V1 config does not rewrite it. Explicit saves persist V2 defaults/version while retaining unknown user fields. PreviewPending/Status use read-only initialization. See [configuration](../configuration.md).
