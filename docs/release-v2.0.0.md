# MiraQueue 🪞 V2.0.0 — release notes

V2 strengthens the queue-first backup workflow while retaining MiraQueue's portable Windows PowerShell application.

## Queue and pending work

Queue schema 2 adds operation/event/baseline fields and rebuildable metadata. A queue-path-derived mutex coordinates reads and writes across application copies. Atomic replacement, strict record validation and ID-aware acknowledgment protect pending work. Parent/child reduction uses an index; restored sources cancel destructive deletes and restored directories receive child snapshots.

Pending preview is read-only. Add/Update/Delete classifications use explicit Exists/Missing/Error observations. A process-local snapshot reuses unchanged results; bounded directory discovery reduces redundant per-file probes. Offline/error states do not become proof of absence. Explicit apply refreshes the snapshot and repeats critical checks.

## Transfers and Full Mirror

`ParallelFileTransfers` controls 1–32 concurrent file jobs (default 4). Conflicting destinations serialize. New directory jobs stage before publication and merge safely when the destination already exists. Progress reports file/tree work, bytes, speed, ETA and failures.

Full Mirror scans complete pairs internally, independently of robocopy's UI language. `RobocopyParallelBatches` remains the compatible setting for bounded pair-scan concurrency. `STRICT` copies new/changed items and deletes verified extras; `UPDATE_KEEP_EXTRAS` preserves extras; `MISSING_ONLY` preserves existing files, including targets created after preview. No policy automatically clears the watcher queue.

## Safety fixes

All queue read paths fail closed on corruption/unsupported records. UTC timestamp normalization preserves precision and compares clear-request cutoffs consistently across both PowerShell JSON engines. Apply uses an exclusive handle instead of reclaiming a live lock by age. Deletes recheck source/root state, containment, exclusions and reparse boundaries. A directory deletion cannot bypass an excluded descendant. Unsafe paths and overlapping trees are rejected. File/type conflicts remain for review.

Uninstall removes exact owned runtime files and preserves unknown DataDir content. Task operations verify the exact action before overwriting/removing a task; process matching uses this installation's full path. Watcher shutdown now unsubscribes the correct event subscription IDs before disposing filesystem watchers. Unicode launch helpers, direct PowerShell elevation and correct Windows argument quoting support portable paths safely. Log retention no longer matches arbitrary `.old` files.

## Upgrade and compatibility

Windows PowerShell 5.1 and PowerShell 7+ remain supported. Close V1 and stop its watcher before replacing application files. Preserve your config and runtime data; never install the example config over them. V2 adds missing defaults in memory, preserves existing preferences, and normalizes valid V1 queue records under lock. Repeat opens are idempotent. Review [upgrade instructions](installation.md) before reinstalling/restarting the watcher.

Product version `V2.0.0` is separate from queue schema `2`. The example config matches public defaults. Existing narrow legacy temporary-file exclusions are retained/protected for compatibility.

## Known boundaries

MiraQueue remains a mirror utility rather than a versioned archive. It compares size/time, does not follow reparse points and cannot provide a filesystem-wide transaction against external writers. A case-only rename is one Windows case-insensitive identity; matching content may retain the destination's existing spelling. Watcher overflow or forced shutdown requires Full Mirror review. Forced process termination/power loss may leave uncommitted events or abandoned staging; handled failures clean their own resources.
