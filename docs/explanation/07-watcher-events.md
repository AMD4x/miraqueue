# Watcher events and recovery

`Start-Watcher` creates one FileSystemWatcher per available source and a separate single-watcher mutex derived from the queue identity. Source events use the MQ namespace. The watcher listens for Created, Changed, Deleted, Renamed and Error; it queues changes only.

Changed files become Upsert. Rename emits old Delete/new Upsert; case-only rename reduces to one case-insensitive identity, avoiding a destructive old-path delete. Created/renamed directories receive safe child snapshots, with batches committed under the queue mutex. Reconciled directory batches compare the parent ID so a newer root event cannot be overwritten.

Debounced work remains in memory until committed; failed commits are not acknowledged. A handled stop requests shutdown, drains queued events and flushes pending memory in finally. A long scan may delay the stop; lifecycle code reports that rather than forcibly killing it. Forced termination or power loss can still lose uncommitted events.

The actual watcher buffer is clamped to 4–64 KiB for Windows/network compatibility while retaining the configured V1 preference. Overflow/source errors are logged with a Full Mirror recovery instruction. A missing source at startup is skipped and requires watcher restart after recovery.
