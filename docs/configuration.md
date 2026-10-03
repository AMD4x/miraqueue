# Configuration — V2.0.0

Config lives beside `MiraQueue.ps1`. New installations start with no pairs or mappings. Existing V1 settings and unknown user properties are preserved; missing defaults are added in memory. An explicit save writes valid JSON atomically.

| Key | Default | Meaning |
| --- | --- | --- |
| `Version` | `"V2.0.0"` | Product marker. Saved as V2.0.0; independent of queue schema 2. |
| `TaskName` | `"MiraQueue"` | Exact root-folder logon task name. Ownership is verified by its action; no wildcards. |
| `DataDir` | `"%LOCALAPPDATA%\\MiraQueue"` | Local runtime storage; cannot be a filesystem root, reparse path or inside a backup pair. |
| `QueueFile` | `"MiraQueue.queue.ndjson"` | Simple queue filename inside DataDir. Cannot alias another runtime file. |
| `LogFile` | `"MiraQueue.log"` | Simple log filename, distinct from the queue and reserved runtime names. |
| `DebounceMs` | `5000` | Delay before committing buffered watcher events (milliseconds); nonnegative. |
| `WatchBufferKB` | `1024` | Retained V1 preference; effective buffer is clamped to 4–64 KiB for Windows/network compatibility. |
| `LogRetentionDays` | `30` | Retention for this log's timestamped rotations. 0 disables age cleanup. |
| `PreserveModifiedTime` | `true` | Preserve source modification times on copied files/directories where supported. |
| `CopyAttributes` | `false` | Apply source attributes after copy; false leaves normal destination defaults. |
| `CopyTempThenReplace` | `true` | Use a sibling temp file then replace. Recommended true; missing-only always publishes without overwrite. |
| `DeleteDestOnSourceDelete` | `true` | Allow pending deletion. False retains delete entries. Does not disable explicitly selected Strict Full Mirror. |
| `TimeToleranceSeconds` | `2` | Absolute modification-time tolerance for size/time comparison; nonnegative seconds. |
| `DirectoryScanMaxItems` | `500000` | Maximum queued child snapshot size. The root directory transfer remains available for full tree copying. |
| `RobocopyThreads` | `8` | Directory staging transport threads, 1–128. |
| `RobocopyRetries` | `1` | Directory staging retry count, nonnegative. |
| `RobocopyWaitSeconds` | `1` | Directory staging seconds between retries, nonnegative. |
| `RobocopyParallelBatches` | `3` | Compatible existing key; now bounds internal Full Mirror pair scans (effective 1–32). |
| `ParallelFileTransfers` | `4` | Concurrent individual file workers, 1–32. Missing/invalid values use 4; conflicting destinations serialize. |
| `DriveMaps` | `{}` | Optional logical drive-root to destination prefix substitutions. No Windows mappings are installed. |
| `Pairs` | `[]` | Unique case-insensitive Name, absolute Source and absolute Dest for each nonoverlapping pair. |
| `GlobalExcludeDirs` | `["System Volume Information","$Recycle.Bin","RECYCLER","Recovery"]` | Directory names/patterns applied to all pairs. |
| `GlobalExcludeFiles` | `["Thumbs.db","desktop.ini","*.tmp","*.crdownload","*.part","*.download","*.mqtmp-*","*.mqbackup-*"]` | File names/patterns applied to all pairs; internal temp/stage names are also protected in code. |
| `PairExcludeDirs` | `{}` | Map of stable pair names to directory-name or relative-subtree patterns. |
| `PairExcludeFiles` | `{}` | Map of stable pair names to filename or relative-file patterns. |

## Pair example

```json
{
  "Name": "Documents",
  "Source": "C:\\Demo\\Documents",
  "Dest": "D:\\DemoBackup\\Documents"
}
```

Names identify queue work and per-pair exclusions; do not manually rename them while work is pending. Changing roots leaves old queued work retained for review rather than redirecting it. Exclusions use PowerShell wildcard syntax; literal brackets in patterns require escaping. Regular filenames containing brackets/Unicode are handled literally by file operations.

## V1 compatibility

The shipped [example](../examples/MiraQueue.config.example.json) has exactly the current default keys. Only its demonstration pair/exclusion-map entries differ; it has no active network map. Never overwrite your own config with it during upgrade.

`TempCleanupMinAgeMinutes` is a legacy V1 property: existing configs preserve it, but V2 no longer uses age-based sweeping as proof that another operation's staging is abandoned. It is omitted from new defaults/examples. Each operation still cleans its own temp/stage files in finally. Other existing exclusion patterns remain unchanged, including narrow legacy temporary-file exclusions.

`Version` is a product marker. Queue and metadata contain their own `SchemaVersion=2`; do not edit either to match a product string.
