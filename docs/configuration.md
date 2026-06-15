# Configuration

MiraQueue creates `MiraQueue.config.json` beside `MiraQueue.ps1` on first run. The runtime folder defaults to `%LOCALAPPDATA%\\MiraQueue`.

| Key | Default | Purpose | Safe Values | Reason |
| --- | --- | --- | --- | --- |
| `Version` | `"V1.0.0"` | Release marker stored in generated config. | Keep equal to shipped release. | Ties support reports to a release. |
| `TaskName` | `"MiraQueue"` | Windows scheduled task name. | Simple unique name. | Keeps watcher installation predictable. |
| `DataDir` | `"%LOCALAPPDATA%\\MiraQueue"` | Runtime folder. | Prefer local user storage. | Keeps runtime files away from user data. |
| `QueueFile` | `"MiraQueue.queue.ndjson"` | Pending queue file. | Keep NDJSON. | Append-friendly and inspectable. |
| `LogFile` | `"MiraQueue.log"` | Log file. | Keep inside DataDir. | Separates operation history. |
| `DebounceMs` | `5000` | Delay before flushing pending events. | 0 or higher. | Reduces repeated editor/copy events. |
| `WatchBufferKB` | `1024` | Watcher buffer size. | 4 or higher. | Reduces event loss during bursts. |
| `LogRetentionDays` | `30` | Rotated log retention. | 0 disables cleanup. | Bounds runtime growth. |
| `PreserveModifiedTime` | `true` | Preserves source modified time. | true for fidelity. | Avoids needless later copies. |
| `CopyAttributes` | `false` | Reserved attribute preference. | false for normal use. | Keeps behavior conservative. |
| `CopyTempThenReplace` | `true` | Uses temp copy before replacement. | true recommended. | Reduces partial final files. |
| `DeleteDestOnSourceDelete` | `true` | Allows pending deletes. | false for manual delete review. | Makes mirror behavior explicit. |
| `TimeToleranceSeconds` | `2` | Timestamp comparison tolerance. | 1-5 typical. | Avoids precision churn. |
| `DirectoryScanMaxItems` | `500000` | Directory snapshot limit. | Raise only for very large trees. | Prevents runaway scans. |
| `RobocopyThreads` | `8` | Robocopy thread count. | 1 or higher. | Balances throughput and load. |
| `RobocopyRetries` | `1` | Robocopy retry count. | 0 or higher. | Keeps failures visible. |
| `RobocopyWaitSeconds` | `1` | Robocopy retry wait. | 0 or higher. | Pairs with retry count. |
| `RobocopyParallelBatches` | `3` | Concurrent full mirror pairs. | 1 or higher. | Speeds multi-pair runs. |
| `TempCleanupMinAgeMinutes` | `10` | Temp cleanup age. | 1 or higher. | Avoids active temp removal. |
| `DriveMaps` | `{}` | Drive mappings. | Drive root to target. | Improves destination health checks. |
| `Pairs` | `[]` | Source/destination relationships. | Name, Source, Dest. | Core backup list. |
| `GlobalExcludeDirs` | `system folders` | Folders skipped for all pairs. | Names or patterns. | Avoids system metadata folders. |
| `GlobalExcludeFiles` | `common temp files` | Files skipped for all pairs. | Names or patterns. | Avoids transient files. |
| `PairExcludeDirs` | `{}` | Per-pair folder skips. | Keys match pair names. | Pair-specific filtering. |
| `PairExcludeFiles` | `{}` | Per-pair file skips. | Keys match pair names. | Pair-specific filtering. |

## Pair Shape

```json
{
  "Name": "DemoProject",
  "Source": "C:\\\\Demo\\\\Source",
  "Dest": "D:\\\\DemoBackup\\\\Source"
}
```

`Name` keys per-pair exclusions. `Source` must be a folder. `Dest` is resolved through drive maps when applicable.
