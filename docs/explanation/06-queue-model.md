# Queue schema 2 and synchronization

The NDJSON queue remains human-inspectable. A schema-2 entry contains SchemaVersion, Id, TimeUtc, PairName, Action, Operation, EventKind, BaselineState, RelPath, Source, Dest, IsDirectory, Size and LastWriteTimeUtc. Action is Upsert/Delete; Operation is Add/Update/Delete. BaselineState is Unknown/Absent/Present. Created events describe the source, not destination absence.

`Get-QueueDictionary` folds history through `Merge-QueueEntryState`, using a per-pair hierarchical index for descendant reduction. Keys compare Windows paths case-insensitively. Parent deletions and restored directory snapshots are reconciled before applying.

Every disk read validates all records. Mutex acquisition, atomic writes and ID comparisons protect migration, watcher commits, classifications and apply acknowledgment. Queue metadata stores counts and queue length/write ticks; it is rebuilt from the queue if stale/corrupt. Destination observations are process-local, never a persistent existence cache.

V1 entries gain the new fields with Unknown baseline. Malformed/unsupported records preserve original bytes and stop processing. Clear Queue is an explicit discard operation with a timestamp cutoff; newer disk/buffered events survive watcher acknowledgment.
