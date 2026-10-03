# Changelog

## V2.0.0

### Added
- Queue schema 2 and metadata; queue-specific synchronization and ID-safe acknowledgments.
- Read-only session previews, destination observations and grouped staged directory jobs.
- ParallelFileTransfers (1–32, default 4), bounded pair scans and optional pending performance metrics.

### Improved
- Indexed hierarchical reduction, selective probes, bounded directory discovery and snapshot reuse.
- Restored-file/directory reconciliation, relative exclusions, directory merge and progress reporting.
- Unicode installation paths, shell argument quoting and graceful watcher shutdown.

### Fixed / Safety
- Malformed/unsupported queues and lock timeouts no longer become empty successful reads.
- Replaced age/PID-based apply lock stealing with a held exclusive file handle.
- Recheck source/root/exclusion state before deletion; reject traversal, overlap and reparse points.
- Full Mirror applies exact planned paths and preserves events arriving during scans; no automatic queue clear.
- Missing-only application never overwrites a destination appearing after preview.
- Internal scans replace locale-dependent robocopy text parsing and fail on partial/error enumeration.
- Uninstall and log retention preserve unrelated files; scheduled-task mutations verify ownership.
- Clear-request acknowledgment preserves newer events; disabled deletes remain pending.
- Correct event subscription cleanup on watcher shutdown, verified with an isolated real watcher.
- UTC timestamp normalization preserves precision and compares clear-request cutoffs consistently on both engines.

### Compatibility / Documentation
- Preserve V1 pairs, settings, exclusions, IDs and effective pending work; idempotent schema migration.
- Keep Windows PowerShell 5.1, PowerShell 7+, public runtime names and the simple offline-capable launcher.
- Rewritten guides, maps, function reference, release notes and reproducible V2 demo GIFs.

## V1.0.0

Initial public release of MiraQueue.

### Added

- Console menu for managing backup pairs, exclusions, settings, status, and lifecycle actions.
- File watcher workflow that stores changes in an NDJSON pending queue.
- Preview Pending and Apply Pending workflows.
- Full Mirror workflow with `STRICT`, `UPDATE_KEEP_EXTRAS`, and `MISSING_ONLY` policies.
- Scheduled watcher task installation, restart, removal, and uninstall flows.
- English documentation, maps, and simulated GIF demos.
