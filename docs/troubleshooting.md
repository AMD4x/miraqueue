# Troubleshooting

| Symptom | Meaning and next action |
| --- | --- |
| Queue read/initialization error | Stop all instances and preserve the original NDJSON. Inspect the reported line; do not clear it to hide corruption. Unknown schemas require a compatible application. |
| Queue lock timeout | Another process is using the same queue, or the named mutex is inaccessible. Retry; a timeout never means an empty queue. |
| Apply blocked | Another Apply/Full Mirror owns the exclusive handle, or the lock path is inaccessible. Wait or fix permissions. A leftover unlocked lock file is normal. |
| Destination unavailable / indeterminate | Reconnect the destination or correct permissions/drive maps. Errors are not absence. Pending work is retained. |
| Source root unavailable | Restore the original source path. MiraQueue refuses to infer deletions from a disconnected source. |
| Pair paths changed since queueing | Existing records refer to previous roots. Restore/review the old pair or use a reviewed Full Mirror and explicitly clear obsolete pending work. Never silently redirect queued deletes. |
| Reparse point / overlap / type conflict | Use separate regular directory trees. Review junctions, links and file-vs-directory conflicts manually. |
| Directory contains excluded content | Parent deletion was blocked. Review exclusions and destination content; excluded descendants must remain protected. |
| Watcher overflow/source error | Run Full Mirror preview to discover events that may have been missed. Network watch buffers are capped at 64 KiB. |
| Watcher still flushing | A graceful stop requested it to flush. Wait for a long directory scan/queue operation, then retry; lifecycle commands do not forcibly kill it. |
| Unrelated task uses TaskName | Choose another task name or manage that resource separately. MiraQueue verifies the exact generated launcher action. |
| Uninstall retains DataDir | It contains files that are not in the runtime allowlist. This is intentional. |

## Diagnose performance

`-TracePendingPerformance` enables per-scan counters/timings for normal application operation. Read-only preview keeps its measurements in memory and does not append a performance log. Metrics distinguish queue reads, reduction, root/target probes, bounded directory enumeration, snapshot reuse and lock waits. Timings overlap; do not sum them into an elapsed total. See [performance notes](explanation/14-design-decisions.md).

The session snapshot is invalidated by queue/context changes and observed disconnects. It cannot notice every external destination change while online. Reopen the application to rediscover all destinations; apply still performs current safety checks.

For execution policy, use the launcher or its documented per-process `-ExecutionPolicy Bypass` invocation. No global policy/registry change is required. Logs and configuration may contain your own paths; review them before sharing a report.
