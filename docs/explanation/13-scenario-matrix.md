# Scenario matrix — V2

| Scenario | Result |
| --- | --- |
| V1 config / queue | Preserve user values/IDs; add defaults and schema fields |
| Reopen after migration | No destructive repeat normalization |
| Malformed / future queue schema | Stop and preserve bytes |
| Concurrent queue writers | No lost successful commits |
| New event during scan/apply | Newer ID survives |
| Source create/change/rename | Queue appropriate effective decision |
| Case-only rename | One case-insensitive upsert; no delete. Matching content may retain the destination spelling. |
| Source restored after delete queued | Reclassify; copy restored directory children |
| Source root unavailable | Preserve backup and pending work |
| Destination offline / permission denied | Error is not absence |
| Preview Pending | Queue, metadata and destination unchanged |
| Apply Pending | Acknowledge successes only |
| Delete disabled | Retain pending and backup |
| Excluded descendant in deleted directory | Block parent deletion |
| Junction / traversal / root overlap | Reject operation |
| Parallel transfers | Bounded workers, matching content hashes |
| Staged tree / existing destination | Publish or merge; preserve extras/exclusions |
| STRICT | New + updates + verified extras deletion |
| UPDATE_KEEP_EXTRAS | New + updates; retain extras |
| MISSING_ONLY | New only; preserve targets appearing after preview |
| Clear queue / newer event | Keep work newer than cutoff |
| Corrupt metadata | Rebuild from valid queue |
| Uninstall shared DataDir | Remove allowlist; retain unknown files |
| Same-name unrelated task | Never remove it |
| Forced process kill / power failure | Possible unflushed events/abandoned stage |
