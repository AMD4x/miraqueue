# Startup, runtime and versions

`Mode` selects Menu, Watch, PreviewPending, ApplyPending, FullMirror, Status, Install, RemoveTask or Uninstall. `NoPause` suppresses result pauses; it is not a dry-run switch. `TracePendingPerformance` enables optional diagnostics. Product version is **V2.0.0**; queue/metadata schema version is **2**, a separate contract.

`Initialize-App` resolves configuration next to the script, expands DataDir, validates runtime filenames and prepares storage under a queue mutex. The mutex identity hashes the absolute queue path, not the script path, so copies sharing storage synchronize. A Unicode pointer identifies the current installation to its hidden watcher launcher.

PreviewPending and Status initialize with `-ReadOnly`: they require an existing config and do not create/migrate storage. The normal menu initializes V1 storage before showing a read-only snapshot. Merely loading configuration preserves its bytes; saving settings writes the current product marker and missing defaults atomically.
