# Status, logs and cleanup

Status reports script/config/runtime paths, queue counts, watcher/task state and pair availability. Logs rotate above 4 MiB. Retention removes only files matching the configured log basename plus the expected timestamp suffix; unrelated *.old files are preserved.

Runtime includes queue, schema-2 metadata, log, reusable apply lock, clear/stop requests, hidden launcher and Unicode script-directory pointer. See the [runtime map](../maps/runtime-files-map.md). Names stay under validated DataDir; no per-machine default destinations are shipped.

Copy/stage temporary paths include MiraQueue-specific prefixes and random IDs. Handled operations clean up only their own paths after containment and reparse checks. The application does not sweep arbitrary aged directory stages, since age cannot prove another operation stopped. A forced crash may leave artifacts that need review with all instances stopped.

Uninstall is an allowlist, not recursive DataDir deletion. It preserves unrelated files/directories and protects configured source/destination trees even if a runtime path is misconfigured.
