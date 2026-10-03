# Complete function reference — V2.0.0

Total functions documented: 198.

Function inventory from the PowerShell AST. Source links and parameter lists are exact. Calls list direct internal PowerShell command references; .NET calls and dynamically launched runspace code are not a complete call graph. Read the linked workflow guides for contracts spanning multiple functions.

### Expand-TextPath

Expands environment variables in user-facing paths before the rest of the script treats them as concrete filesystem locations.

- Source: [MiraQueue.ps1:46](../../MiraQueue.ps1#L46)
- Parameters: `Path`.
- Direct internal calls: none.

### New-DefaultConfig

Returns the neutral V2.0.0 defaults. Queue schema version is a separate contract.

- Source: [MiraQueue.ps1:52](../../MiraQueue.ps1#L52)
- Parameters: none.
- Direct internal calls: none.

### Write-AtomicText

Writes a same-directory temporary UTF-8 file, atomically replaces the target and cleans the temporary file in finally.

- Source: [MiraQueue.ps1:96](../../MiraQueue.ps1#L96)
- Parameters: `Path`, `Text`.
- Direct internal calls: none.

### Save-Config

Atomically persists validated configuration, invalidates the snapshot and refreshes the owned watcher.

- Source: [MiraQueue.ps1:106](../../MiraQueue.ps1#L106)
- Parameters: none.
- Direct internal calls: `Ensure-ConfigShape`, `Refresh-WatcherAfterConfigChange`, `Write-AtomicText`, `Write-Log`.

### Refresh-WatcherAfterConfigChange

Coordinates watcher restart after config edits so changed paths or settings are picked up without asking the user to find the process manually.

- Source: [MiraQueue.ps1:114](../../MiraQueue.ps1#L114)
- Parameters: none.
- Direct internal calls: `Get-OwnedScheduledTask`, `Get-WatcherProcesses`, `Stop-KnownWatcherProcesses`, `Wait-ScheduledTaskNotRunning`, `Wait-ScheduledWatcherStarted`, `Write-Color`, `Write-Log`.

### Wait-ScheduledTaskNotRunning

Polls the owned task until it stops or the retry limit is reached.

- Source: [MiraQueue.ps1:142](../../MiraQueue.ps1#L142)
- Parameters: `TaskName`, `Attempts`, `DelayMs`.
- Direct internal calls: `Get-OwnedScheduledTask`.

### Wait-ScheduledWatcherStarted

Polls the owned task and watcher processes until startup is observed or the retry limit is reached.

- Source: [MiraQueue.ps1:157](../../MiraQueue.ps1#L157)
- Parameters: `TaskName`, `Attempts`, `DelayMs`.
- Direct internal calls: `Get-OwnedScheduledTask`, `Get-WatcherProcesses`.

### Initialize-App

Loads config, validates runtime paths and initializes queue storage; ReadOnly skips file creation and migration.

- Source: [MiraQueue.ps1:173](../../MiraQueue.ps1#L173)
- Parameters: `ReadOnly`.
- Direct internal calls: `Assert-NoReparsePath`, `Ensure-ConfigShape`, `Enter-QueueMutex`, `Exit-QueueMutex`, `Expand-TextPath`, `Initialize-QueueStorage`, `New-DefaultConfig`, `Rotate-LogIfNeeded`, `Test-RuntimePathProtected`, `Write-AtomicText`.

### Ensure-ConfigShape

Adds missing defaults while preserving user settings; validates identity/runtime fields and bounds file concurrency.

- Source: [MiraQueue.ps1:229](../../MiraQueue.ps1#L229)
- Parameters: none.
- Direct internal calls: `Ensure-AllPairExclusionKeys`, `Get-Pairs`, `New-DefaultConfig`, `Normalize-QueueRelPath`.

### Get-Array

Normalizes null, scalar and collection values for array-based callers.

- Source: [MiraQueue.ps1:266](../../MiraQueue.ps1#L266)
- Parameters: `Value`.
- Direct internal calls: none.

### Get-Pairs

Returns the configured source/destination pairs.

- Source: [MiraQueue.ps1:275](../../MiraQueue.ps1#L275)
- Parameters: none.
- Direct internal calls: `Get-Array`.

### Set-Pairs

Replaces the in-memory pair list and ensures its exclusion keys exist.

- Source: [MiraQueue.ps1:279](../../MiraQueue.ps1#L279)
- Parameters: `Pairs`.
- Direct internal calls: `Ensure-AllPairExclusionKeys`.

### Get-MapArray

Reads an array from a named configuration map, returning an empty array for a missing key.

- Source: [MiraQueue.ps1:285](../../MiraQueue.ps1#L285)
- Parameters: `MapName`, `Key`.
- Direct internal calls: `Get-Array`.

### Set-MapArray

Creates or replaces an array entry in a named configuration map.

- Source: [MiraQueue.ps1:294](../../MiraQueue.ps1#L294)
- Parameters: `MapName`, `Key`, `Values`.
- Direct internal calls: none.

### Ensure-AllPairExclusionKeys

Adds missing directory and file exclusion arrays for each configured pair.

- Source: [MiraQueue.ps1:304](../../MiraQueue.ps1#L304)
- Parameters: none.
- Direct internal calls: `Get-Pairs`, `Set-MapArray`.

### Write-Color

Writes console text in the requested color, optionally without a newline.

- Source: [MiraQueue.ps1:316](../../MiraQueue.ps1#L316)
- Parameters: `Text`, `Color`, `NoNewLine`.
- Direct internal calls: none.

### Write-Log

Appends a timestamped log entry after rotation; logging failures do not interrupt file operations.

- Source: [MiraQueue.ps1:322](../../MiraQueue.ps1#L322)
- Parameters: `Level`, `Message`.
- Direct internal calls: `Rotate-LogIfNeeded`.

### Rotate-LogIfNeeded

Rotates logs above 4 MiB and expires only timestamped rotations of this configured log basename.

- Source: [MiraQueue.ps1:332](../../MiraQueue.ps1#L332)
- Parameters: none.
- Direct internal calls: `Remove-OwnedPath`.

### Clear-Screen

Clears the console when the host supports it.

- Source: [MiraQueue.ps1:347](../../MiraQueue.ps1#L347)
- Parameters: none.
- Direct internal calls: none.

### Center-Text

Pads text to center it within a requested width.

- Source: [MiraQueue.ps1:351](../../MiraQueue.ps1#L351)
- Parameters: `Text`, `Width`.
- Direct internal calls: none.

### Fit-Cell

Truncates or pads text to fit a table column.

- Source: [MiraQueue.ps1:359](../../MiraQueue.ps1#L359)
- Parameters: `Text`, `Width`.
- Direct internal calls: none.

### Write-BoxHeader

Renders a bordered title and optional subtitle.

- Source: [MiraQueue.ps1:367](../../MiraQueue.ps1#L367)
- Parameters: `Title`, `Subtitle`.
- Direct internal calls: `Center-Text`, `Write-Color`.

### Show-Header

Clears the screen and renders the application header.

- Source: [MiraQueue.ps1:382](../../MiraQueue.ps1#L382)
- Parameters: `Title`, `Subtitle`.
- Direct internal calls: `Clear-Screen`, `Write-BoxHeader`.

### Show-SpinnerLine

Updates a console spinner and its status message.

- Source: [MiraQueue.ps1:389](../../MiraQueue.ps1#L389)
- Parameters: `Text`, `Cycles`.
- Direct internal calls: none.

### Get-ConsoleWidthSafe

Reads the console width with a fallback for hosts that do not expose it.

- Source: [MiraQueue.ps1:399](../../MiraQueue.ps1#L399)
- Parameters: none.
- Direct internal calls: none.

### Format-ByteSize

Formats byte counts with a readable size unit.

- Source: [MiraQueue.ps1:411](../../MiraQueue.ps1#L411)
- Parameters: `Bytes`.
- Direct internal calls: none.

### Format-ByteSpeed

Formats transfer speed as a byte size per second.

- Source: [MiraQueue.ps1:427](../../MiraQueue.ps1#L427)
- Parameters: `BytesPerSecond`.
- Direct internal calls: `Format-ByteSize`.

### Format-CompactDuration

Formats elapsed or remaining time for progress displays.

- Source: [MiraQueue.ps1:433](../../MiraQueue.ps1#L433)
- Parameters: `Seconds`.
- Direct internal calls: none.

### Format-ApplyProgressBar

Builds a fixed-width progress bar from a percentage.

- Source: [MiraQueue.ps1:442](../../MiraQueue.ps1#L442)
- Parameters: `Percent`, `Width`.
- Direct internal calls: none.

### Get-ApplyProgressLayout

Chooses progress column widths for the available console width.

- Source: [MiraQueue.ps1:453](../../MiraQueue.ps1#L453)
- Parameters: none.
- Direct internal calls: `Get-ConsoleWidthSafe`.

### Get-ApplyEntryTotalBytes

Returns the byte total for a file or grouped directory transfer.

- Source: [MiraQueue.ps1:515](../../MiraQueue.ps1#L515)
- Parameters: `Entry`.
- Direct internal calls: none.

### Get-ApplyProgressPercent

Calculates the displayed completion percentage for a progress row.

- Source: [MiraQueue.ps1:526](../../MiraQueue.ps1#L526)
- Parameters: `Row`.
- Direct internal calls: none.

### Get-ApplyProgressSizeText

Formats copied and total byte counts for a progress row.

- Source: [MiraQueue.ps1:535](../../MiraQueue.ps1#L535)
- Parameters: `Row`.
- Direct internal calls: `Format-ByteSize`.

### Get-ApplyProgressTiming

Calculates transfer speed and estimated remaining time for a progress row.

- Source: [MiraQueue.ps1:541](../../MiraQueue.ps1#L541)
- Parameters: `Row`.
- Direct internal calls: `Format-ByteSpeed`, `Format-CompactDuration`.

### Get-ApplyStatusColor

Selects a console color for an apply status.

- Source: [MiraQueue.ps1:561](../../MiraQueue.ps1#L561)
- Parameters: `StatusOrRow`.
- Direct internal calls: none.

### Format-ApplyProgressRow

Formats one progress row using the current column layout.

- Source: [MiraQueue.ps1:584](../../MiraQueue.ps1#L584)
- Parameters: `Table`, `Row`.
- Direct internal calls: `Fit-Cell`, `Format-ApplyProgressBar`, `Get-ApplyProgressPercent`, `Get-ApplyProgressSizeText`, `Get-ApplyProgressTiming`.

### Write-ApplyProgressLine

Writes a progress line with its selected color.

- Source: [MiraQueue.ps1:601](../../MiraQueue.ps1#L601)
- Parameters: `Text`, `Color`, `Width`.
- Direct internal calls: `Write-Color`.

### Get-ApplyProgressBorder

Builds a border matching the progress table column widths.

- Source: [MiraQueue.ps1:607](../../MiraQueue.ps1#L607)
- Parameters: `Layout`.
- Direct internal calls: none.

### Get-ApplyProgressHeaderRow

Builds the progress table column headings.

- Source: [MiraQueue.ps1:614](../../MiraQueue.ps1#L614)
- Parameters: `Layout`.
- Direct internal calls: `Center-Text`.

### Get-ApplyProgressSummary

Summarizes overall progress across the transfer rows.

- Source: [MiraQueue.ps1:628](../../MiraQueue.ps1#L628)
- Parameters: `Table`.
- Direct internal calls: none.

### Get-ApplyProgressQueuedStatus

Selects the initial queued status for a transfer entry.

- Source: [MiraQueue.ps1:640](../../MiraQueue.ps1#L640)
- Parameters: `Entry`.
- Direct internal calls: none.

### Test-ApplyProgressEntryVisible

Checks whether an entry belongs to the selected progress display set.

- Source: [MiraQueue.ps1:647](../../MiraQueue.ps1#L647)
- Parameters: `Entry`, `VisibleEntryKeys`.
- Direct internal calls: `Get-QueueEntryKey`.

### New-ApplyProgressRow

Creates the initial display state and byte counters for a transfer entry.

- Source: [MiraQueue.ps1:654](../../MiraQueue.ps1#L654)
- Parameters: `Entry`, `No`.
- Direct internal calls: `Get-ApplyEntryTotalBytes`, `Get-ApplyProgressQueuedStatus`.

### Get-ApplyProgressVisibleCount

Limits the number of visible progress rows to the available console height.

- Source: [MiraQueue.ps1:676](../../MiraQueue.ps1#L676)
- Parameters: `TotalRows`.
- Direct internal calls: none.

### Get-ApplyProgressVisibleStart

Selects a viewport start that includes the current progress row.

- Source: [MiraQueue.ps1:692](../../MiraQueue.ps1#L692)
- Parameters: `Table`, `CurrentIndex`.
- Direct internal calls: none.

### Write-ApplyProgressAtLine

Writes progress text at a specified console line.

- Source: [MiraQueue.ps1:712](../../MiraQueue.ps1#L712)
- Parameters: `Line`, `Text`, `Color`, `Width`.
- Direct internal calls: none.

### Redraw-ApplyProgressViewport

Redraws the visible progress rows and their table frame.

- Source: [MiraQueue.ps1:721](../../MiraQueue.ps1#L721)
- Parameters: `Table`, `Initial`.
- Direct internal calls: `Format-ApplyProgressRow`, `Get-ApplyProgressBorder`, `Get-ApplyProgressHeaderRow`, `Get-ApplyProgressSummary`, `Get-ApplyStatusColor`, `Write-ApplyProgressAtLine`, `Write-ApplyProgressLine`.

### New-ApplyProgressTable

Initializes the progress table layout, rows and viewport state.

- Source: [MiraQueue.ps1:757](../../MiraQueue.ps1#L757)
- Parameters: `Entries`, `VisibleEntryKeys`.
- Direct internal calls: `Get-ApplyProgressLayout`, `Get-ApplyProgressVisibleCount`, `New-ApplyProgressRow`, `Redraw-ApplyProgressViewport`, `Test-ApplyProgressEntryVisible`.

### Add-ApplyProgressVisibleRow

Adds a transfer row to the progress display.

- Source: [MiraQueue.ps1:792](../../MiraQueue.ps1#L792)
- Parameters: `Table`, `EntryIndex`.
- Direct internal calls: `Get-ApplyProgressVisibleCount`, `New-ApplyProgressRow`, `Redraw-ApplyProgressViewport`.

### Resolve-ApplyProgressRowIndex

Finds the progress row corresponding to a transfer entry.

- Source: [MiraQueue.ps1:810](../../MiraQueue.ps1#L810)
- Parameters: `Table`, `Index`, `ShowIfHidden`.
- Direct internal calls: `Add-ApplyProgressVisibleRow`.

### Update-ApplyProgressRow

Updates a transfer row's status, byte counters and rendered progress.

- Source: [MiraQueue.ps1:827](../../MiraQueue.ps1#L827)
- Parameters: `Table`, `Index`, `Status`, `CopiedBytes`, `TotalBytes`, `StartedAt`, `Complete`, `ForceRender`, `ShowIfHidden`.
- Direct internal calls: `Format-ApplyProgressRow`, `Get-ApplyProgressSummary`, `Get-ApplyProgressVisibleStart`, `Get-ApplyStatusColor`, `Redraw-ApplyProgressViewport`, `Resolve-ApplyProgressRowIndex`.

### Wait-Back

Waits for the user to return from a console screen.

- Source: [MiraQueue.ps1:886](../../MiraQueue.ps1#L886)
- Parameters: `Prompt`.
- Direct internal calls: `Write-Color`.

### Read-KeyChoice

Collects r ea d k ey ch oi ce input from the console while preserving Escape/cancel behavior.

- Source: [MiraQueue.ps1:894](../../MiraQueue.ps1#L894)
- Parameters: `Prompt`.
- Direct internal calls: `Write-Color`.

### Read-LineOrEsc

Collects r ea d l in eo re sc input from the console while preserving Escape/cancel behavior.

- Source: [MiraQueue.ps1:906](../../MiraQueue.ps1#L906)
- Parameters: `Prompt`.
- Direct internal calls: `Write-Color`.

### Read-NumberOrEsc

Collects r ea d n um be ro re sc input from the console while preserving Escape/cancel behavior.

- Source: [MiraQueue.ps1:928](../../MiraQueue.ps1#L928)
- Parameters: `Prompt`.
- Direct internal calls: `Read-LineOrEsc`, `Write-Color`.

### Read-EnterOrEsc

Collects r ea d e nt er or es c input from the console while preserving Escape/cancel behavior.

- Source: [MiraQueue.ps1:939](../../MiraQueue.ps1#L939)
- Parameters: `Prompt`.
- Direct internal calls: `Write-Color`.

### Normalize-PathText

Trims path quotes and whitespace, normalizes separators and removes non-root trailing separators.

- Source: [MiraQueue.ps1:950](../../MiraQueue.ps1#L950)
- Parameters: `Path`.
- Direct internal calls: none.

### Format-ErrorSummary

Maps an error message to a short display category.

- Source: [MiraQueue.ps1:958](../../MiraQueue.ps1#L958)
- Parameters: `Message`.
- Direct internal calls: none.

### Get-AutoPairName

Derives a pair name from a source or destination path.

- Source: [MiraQueue.ps1:973](../../MiraQueue.ps1#L973)
- Parameters: `Source`, `Dest`.
- Direct internal calls: `Normalize-PathText`.

### Resolve-DestinationPath

Substitutes configured drive-map prefixes in destination paths.

- Source: [MiraQueue.ps1:993](../../MiraQueue.ps1#L993)
- Parameters: `Path`.
- Direct internal calls: none.

### Get-RelativePath

Returns a relative child path only after verifying a strict root boundary, including the separator.

- Source: [MiraQueue.ps1:1012](../../MiraQueue.ps1#L1012)
- Parameters: `Root`, `Path`.
- Direct internal calls: `Test-PathInsideRoot`.

### Join-PathSafe

Validates a relative path and verifies that its canonical result remains strictly inside the supplied root.

- Source: [MiraQueue.ps1:1018](../../MiraQueue.ps1#L1018)
- Parameters: `Base`, `Rel`.
- Direct internal calls: `Normalize-QueueRelPath`, `Test-PathInsideRoot`.

### Assert-NoReparsePath

Rejects reparse points or inspection errors on a path and its ancestors; missing future child paths are allowed.

- Source: [MiraQueue.ps1:1027](../../MiraQueue.ps1#L1027)
- Parameters: `Path`.
- Direct internal calls: `Get-ExactPathProbe`.

### Assert-PairLayout

Requires absolute nonoverlapping roots and prevents destinations from overlapping configured sources.

- Source: [MiraQueue.ps1:1042](../../MiraQueue.ps1#L1042)
- Parameters: `Pair`.
- Direct internal calls: `Assert-NoReparsePath`, `Expand-TextPath`, `Get-Pairs`, `Resolve-DestinationPath`, `Test-PathInsideRoot`.

### Get-SafeEntryPaths

Recomputes contained current paths, rejects reparse points and refuses queued work redirected by config edits.

- Source: [MiraQueue.ps1:1059](../../MiraQueue.ps1#L1059)
- Parameters: `Pair`, `Entry`.
- Direct internal calls: `Assert-NoReparsePath`, `Assert-PairLayout`, `Expand-TextPath`, `Join-PathSafe`, `Normalize-QueueRelPath`, `Resolve-DestinationPath`.

### Get-SafeTreeItems

Enumerates with terminating errors, prunes excluded subtrees and rejects encountered reparse points.

- Source: [MiraQueue.ps1:1074](../../MiraQueue.ps1#L1074)
- Parameters: `Root`, `Pair`, `EquivalentRoot`.
- Direct internal calls: `Assert-NoReparsePath`, `Get-RelativePath`, `Join-PathSafe`, `Test-Excluded`.

### Remove-OwnedPath

Checks containment and reparse boundaries, clears ReadOnly when necessary, deletes with .NET and verifies absence.

- Source: [MiraQueue.ps1:1091](../../MiraQueue.ps1#L1091)
- Parameters: `Root`, `Path`, `Recurse`.
- Direct internal calls: `Assert-NoReparsePath`, `Get-ExactPathProbe`, `Get-SafeTreeItems`, `Test-PathInsideRoot`.

### Remove-VerifiedDestination

Checks exclusions throughout a directory, then reconfirms roots and source absence before deleting the target.

- Source: [MiraQueue.ps1:1115](../../MiraQueue.ps1#L1115)
- Parameters: `Pair`, `RelPath`.
- Direct internal calls: `Assert-NoReparsePath`, `Assert-PairLayout`, `Get-ExactPathProbe`, `Get-RelativePath`, `Get-SafeTreeItems`, `Join-PathSafe`, `Remove-OwnedPath`, `Resolve-DestinationPath`, `Test-Excluded`.

### Test-NameMatchesAny

Checks a name against a collection of exclusion patterns.

- Source: [MiraQueue.ps1:1139](../../MiraQueue.ps1#L1139)
- Parameters: `Text`, `Patterns`.
- Direct internal calls: none.

### Test-RelativeDirExcluded

Matches a normalized relative directory or descendant against a relative exclusion pattern.

- Source: [MiraQueue.ps1:1148](../../MiraQueue.ps1#L1148)
- Parameters: `RelPath`, `Pattern`.
- Direct internal calls: none.

### Convert-PairExcludeDirForRobocopy

Resolves relative per-pair directory exclusions against the original source root for directory transport.

- Source: [MiraQueue.ps1:1157](../../MiraQueue.ps1#L1157)
- Parameters: `Pair`, `Pattern`.
- Direct internal calls: `Join-PathSafe`.

### Test-Excluded

Checks global and per-pair exclusions for a relative file or directory path.

- Source: [MiraQueue.ps1:1165](../../MiraQueue.ps1#L1165)
- Parameters: `Pair`, `FullPath`, `IsDirectory`.
- Direct internal calls: `Get-Array`, `Get-MapArray`, `Get-RelativePath`, `Test-NameMatchesAny`, `Test-RelativeDirExcluded`.

### Test-DestRootAvailable

Checks destination root availability before operations that depend on it.

- Source: [MiraQueue.ps1:1212](../../MiraQueue.ps1#L1212)
- Parameters: `DestPath`.
- Direct internal calls: `Resolve-DestinationPath`.

### Initialize-PhysicalPathApi

Loads the small Windows native path-resolution interop type lazily.

- Source: [MiraQueue.ps1:1224](../../MiraQueue.ps1#L1224)
- Parameters: none.
- Direct internal calls: none.

### Get-PhysicalDestinationKey

Resolves a destination ancestor for conflict serialization; uncertainty falls back to a shared serialization group.

- Source: [MiraQueue.ps1:1262](../../MiraQueue.ps1#L1262)
- Parameters: `Destination`.
- Direct internal calls: `Initialize-PhysicalPathApi`, `Write-Log`.

### Test-TcpPortQuick

Performs a bounded TCP readiness hint and closes the client; a positive hint is not deletion authorization.

- Source: [MiraQueue.ps1:1288](../../MiraQueue.ps1#L1288)
- Parameters: `Server`, `Port`, `TimeoutMs`.
- Direct internal calls: none.

### Test-DestRootAvailableFast

Caches a short-lived root readiness hint for status displays.

- Source: [MiraQueue.ps1:1311](../../MiraQueue.ps1#L1311)
- Parameters: `DestPath`.
- Direct internal calls: `Resolve-DestinationPath`, `Test-TcpPortQuick`.

### Enter-ApplyLock

Acquires and holds an exclusive file handle for Apply, Full Mirror or uninstall; never steals a lock by age.

- Source: [MiraQueue.ps1:1345](../../MiraQueue.ps1#L1345)
- Parameters: `Operation`, `Quiet`.
- Direct internal calls: `Wait-Back`, `Write-Color`, `Write-Log`.

### Exit-ApplyLock

Disposes this operation's lock handle; the reusable unlocked lock file remains until uninstall.

- Source: [MiraQueue.ps1:1365](../../MiraQueue.ps1#L1365)
- Parameters: none.
- Direct internal calls: none.

### Find-PairByName

Finds a configured pair by its name.

- Source: [MiraQueue.ps1:1370](../../MiraQueue.ps1#L1370)
- Parameters: `Name`.
- Direct internal calls: `Get-Pairs`.

### New-QueueEntry

Creates a schema-2 source event with a stable random ID and explicit operation/event/baseline fields.

- Source: [MiraQueue.ps1:1378](../../MiraQueue.ps1#L1378)
- Parameters: `Pair`, `FullPath`, `Action`, `KnownIsDirectory`, `EventKind`, `BaselineState`.
- Direct internal calls: `Get-RelativePath`, `Join-PathSafe`, `Resolve-DestinationPath`.

### ConvertTo-UtcTimestamp

Normalizes string or DateTime JSON values to invariant UTC without losing subsecond precision; shared by queue writes and cutoff comparisons.

- Source: [MiraQueue.ps1:1423](../../MiraQueue.ps1#L1423)
- Parameters: `Value`.
- Direct internal calls: none.

### ConvertTo-QueueV2Entry

Validates and normalizes V1 or V2 records; preserves IDs and rejects invalid or unsupported schemas.

- Source: [MiraQueue.ps1:1434](../../MiraQueue.ps1#L1434)
- Parameters: `Entry`.
- Direct internal calls: `ConvertTo-UtcTimestamp`, `Normalize-QueueRelPath`.

### Add-PendingMetric

Accumulates optional elapsed times and counts globally and by pair/operation.

- Source: [MiraQueue.ps1:1467](../../MiraQueue.ps1#L1467)
- Parameters: `Name`, `Started`, `Count`, `Pair`, `Operation`.
- Direct internal calls: none.

### Invoke-PendingPathProbe

Wraps an exact path probe with optional performance attribution.

- Source: [MiraQueue.ps1:1488](../../MiraQueue.ps1#L1488)
- Parameters: `Path`, `Kind`, `Pair`, `Operation`.
- Direct internal calls: `Add-PendingMetric`, `Get-ExactPathProbe`.

### Enter-QueueMutex

Acquires the queue-path-specific mutex with timeout and abandoned-owner handling; returns null on acquisition failure.

- Source: [MiraQueue.ps1:1495](../../MiraQueue.ps1#L1495)
- Parameters: `TimeoutMs`.
- Direct internal calls: `Add-PendingMetric`.

### Exit-QueueMutex

Releases/disposes the acquired mutex and records optional hold time.

- Source: [MiraQueue.ps1:1517](../../MiraQueue.ps1#L1517)
- Parameters: `Mutex`.
- Direct internal calls: `Add-PendingMetric`.

### Read-QueueEntriesUnlocked

Reads and validates every nonblank NDJSON record; throws on read/parse/schema failure instead of dropping work.

- Source: [MiraQueue.ps1:1527](../../MiraQueue.ps1#L1527)
- Parameters: none.
- Direct internal calls: `Add-PendingMetric`, `ConvertTo-QueueV2Entry`.

### Read-QueueEntries

Acquires the queue mutex and returns validated records; timeout is an error, not an empty queue.

- Source: [MiraQueue.ps1:1545](../../MiraQueue.ps1#L1545)
- Parameters: none.
- Direct internal calls: `Enter-QueueMutex`, `Exit-QueueMutex`, `Read-QueueEntriesUnlocked`.

### Get-QueuePathNode

Finds or creates a per-pair node in the transient hierarchical path index.

- Source: [MiraQueue.ps1:1551](../../MiraQueue.ps1#L1551)
- Parameters: `PathIndex`, `Entry`, `Create`.
- Direct internal calls: `Normalize-QueueRelPath`.

### Remove-QueueDescendants

Removes relevant descendants through the index, or a small dictionary fallback, optionally only known-new work.

- Source: [MiraQueue.ps1:1569](../../MiraQueue.ps1#L1569)
- Parameters: `Dictionary`, `Parent`, `OnlyNew`, `PathIndex`.
- Direct internal calls: `Get-QueuePathNode`, `Normalize-QueueRelPath`.

### Merge-QueueEntryState

Reduces one normalized event into effective state while preserving baseline and parent/child semantics.

- Source: [MiraQueue.ps1:1601](../../MiraQueue.ps1#L1601)
- Parameters: `Dictionary`, `Incoming`, `PathIndex`.
- Direct internal calls: `ConvertTo-QueueV2Entry`, `Get-QueueEntryKey`, `Get-QueuePathNode`, `Remove-QueueDescendants`.

### Get-QueueDictionary

Builds case-insensitive effective queue state with a shared path index for the batch.

- Source: [MiraQueue.ps1:1640](../../MiraQueue.ps1#L1640)
- Parameters: `Entries`, `PathIndex`.
- Direct internal calls: `Add-PendingMetric`, `Merge-QueueEntryState`.

### Get-LatestQueueEntries

Returns indexed effective queue entries sorted for stable storage/display.

- Source: [MiraQueue.ps1:1651](../../MiraQueue.ps1#L1651)
- Parameters: `Entries`.
- Direct internal calls: `Add-PendingMetric`, `Get-QueueDictionary`.

### Remove-OrphanedUpserts

Filters upserts covered by a delete for the same path or an ancestor in the same pair.

- Source: [MiraQueue.ps1:1659](../../MiraQueue.ps1#L1659)
- Parameters: `Entries`.
- Direct internal calls: `Add-PendingMetric`, `Get-QueueEntryKey`, `Normalize-QueueRelPath`.

### Write-QueueMetaUnlocked

Atomically writes schema-2 counts and queue length/write-time fingerprint; caller holds the queue mutex.

- Source: [MiraQueue.ps1:1683](../../MiraQueue.ps1#L1683)
- Parameters: `Entries`.
- Direct internal calls: `Remove-OwnedPath`.

### Get-QueueFileFingerprint

Returns queue length and last-write ticks for in-process snapshot invalidation.

- Source: [MiraQueue.ps1:1708](../../MiraQueue.ps1#L1708)
- Parameters: none.
- Direct internal calls: none.

### Get-PendingPairIndex

Indexes configured pairs and resolved roots for a scan, avoiding repeated pair/drive-map searches.

- Source: [MiraQueue.ps1:1723](../../MiraQueue.ps1#L1723)
- Parameters: none.
- Direct internal calls: `Get-Pairs`, `Resolve-DestinationPath`.

### Get-PendingDirectoryNames

Enumerates requested names nonrecursively with a cap and early exit; partial absence never proves a missing item.

- Source: [MiraQueue.ps1:1737](../../MiraQueue.ps1#L1737)
- Parameters: `Directory`, `Limit`, `Wanted`.
- Direct internal calls: `Add-PendingMetric`, `Format-ErrorSummary`.

### Add-PendingDiscoveryAttribution

Allocates shared directory-enumeration time across logical requests without double-counting physical totals.

- Source: [MiraQueue.ps1:1768](../../MiraQueue.ps1#L1768)
- Parameters: `Requests`, `ElapsedMs`.
- Direct internal calls: none.

### Resolve-PendingDestinationObservations

Uses sparse exact probes or bounded dense enumeration; negative results require root confirmation.

- Source: [MiraQueue.ps1:1783](../../MiraQueue.ps1#L1783)
- Parameters: `Requests`.
- Direct internal calls: `Add-PendingDiscoveryAttribution`, `Add-PendingMetric`, `Get-PendingDirectoryNames`, `Invoke-PendingPathProbe`.

### Get-PendingDestinationState

Probes distinct roots and reports pair availability and observed root-state transitions.

- Source: [MiraQueue.ps1:1865](../../MiraQueue.ps1#L1865)
- Parameters: `PreviousRootOnline`, `PairIndex`.
- Direct internal calls: `Get-PendingPairIndex`, `Invoke-PendingPathProbe`.

### Save-PendingClassifications

Commits changed upsert baselines only for matching IDs, capturing final entries/fingerprint under one lock.

- Source: [MiraQueue.ps1:1893](../../MiraQueue.ps1#L1893)
- Parameters: `Classifications`, `PassThru`.
- Direct internal calls: `Enter-QueueMutex`, `Exit-QueueMutex`, `Get-QueueDictionary`, `Get-QueueFileFingerprint`, `Read-QueueEntriesUnlocked`, `Write-Log`, `Write-QueueEntriesUnlocked`.

### Get-ExactPathProbe

Distinguishes Exists, Missing and Error using .NET attribute reads rather than treating all failures as absence.

- Source: [MiraQueue.ps1:1931](../../MiraQueue.ps1#L1931)
- Parameters: `Path`.
- Direct internal calls: `Format-ErrorSummary`.

### Sync-PendingDeleteEntries

Reconciles restored sources and obsolete deletes; ReadOnly produces decisions in memory without queue writes.

- Source: [MiraQueue.ps1:1956](../../MiraQueue.ps1#L1956)
- Parameters: `Entries`, `DestinationState`, `ReadOnly`.
- Direct internal calls: `Enter-QueueMutex`, `Exit-QueueMutex`, `Find-PairByName`, `Get-QueueDictionary`, `Get-QueueEntryKey`, `Get-SafeEntryPaths`, `Get-SafeTreeItems`, `Invoke-PendingPathProbe`, `Merge-QueueEntryState`, `New-QueueEntry`, `Read-QueueEntriesUnlocked`, `Write-Log`, `Write-QueueEntriesUnlocked`.

### Queue-ReconciledDirectorySnapshot

Rechecks a restored directory's ID/action before expanding its children.

- Source: [MiraQueue.ps1:2074](../../MiraQueue.ps1#L2074)
- Parameters: `Entry`.
- Direct internal calls: `Enter-QueueMutex`, `Exit-QueueMutex`, `Get-ExactPathProbe`, `Get-QueueDictionary`, `Get-QueueEntryKey`, `Queue-DirectorySnapshot`, `Read-QueueEntriesUnlocked`, `Write-Log`.

### Sync-PendingSessionSnapshot

Reuses stable observations, reconciles current work and reports counts; ReadOnly omits disk/log commits.

- Source: [MiraQueue.ps1:2097](../../MiraQueue.ps1#L2097)
- Parameters: `RefreshDestinations`, `ShowProgress`, `ReadOnly`.
- Direct internal calls: `Add-PendingMetric`, `Get-LatestQueueEntries`, `Get-PendingDestinationState`, `Get-PendingPairIndex`, `Get-QueueEntryKey`, `Get-QueueFileFingerprint`, `Queue-ReconciledDirectorySnapshot`, `Read-QueueEntries`, `Remove-OrphanedUpserts`, `Resolve-PendingDestinationObservations`, `Save-PendingClassifications`, `Sync-PendingDeleteEntries`, `Write-Log`.

### Write-QueueEntriesUnlocked

Atomically writes normalized NDJSON, then updates rebuildable metadata; never deletes the original as a fallback.

- Source: [MiraQueue.ps1:2240](../../MiraQueue.ps1#L2240)
- Parameters: `Entries`, `PassThru`.
- Direct internal calls: `Add-PendingMetric`, `Get-LatestQueueEntries`, `Remove-OwnedPath`, `Write-Log`, `Write-QueueMetaUnlocked`.

### Write-QueueEntries

Serializes an explicit whole-queue replacement under the queue mutex and reports success.

- Source: [MiraQueue.ps1:2268](../../MiraQueue.ps1#L2268)
- Parameters: `Entries`.
- Direct internal calls: `Enter-QueueMutex`, `Exit-QueueMutex`, `Write-Log`, `Write-QueueEntriesUnlocked`.

### Test-QueueMetaFresh

Checks metadata schema plus queue length/write ticks; metadata is a cache rather than pending-work authority.

- Source: [MiraQueue.ps1:2275](../../MiraQueue.ps1#L2275)
- Parameters: none.
- Direct internal calls: none.

### Initialize-QueueStorage

Migrates/normalizes valid records under mutex when metadata is stale; invalid queues remain untouched.

- Source: [MiraQueue.ps1:2284](../../MiraQueue.ps1#L2284)
- Parameters: none.
- Direct internal calls: `Enter-QueueMutex`, `Exit-QueueMutex`, `Read-QueueEntriesUnlocked`, `Test-QueueMetaFresh`, `Write-Log`, `Write-QueueEntriesUnlocked`.

### Merge-QueueEntriesToDisk

Reads, reduces and writes a batch under one mutex so concurrent writer commits are not lost.

- Source: [MiraQueue.ps1:2299](../../MiraQueue.ps1#L2299)
- Parameters: `Entries`.
- Direct internal calls: `Enter-QueueMutex`, `Exit-QueueMutex`, `Get-QueueDictionary`, `Merge-QueueEntryState`, `Read-QueueEntriesUnlocked`, `Write-Log`, `Write-QueueEntriesUnlocked`.

### Remove-AppliedQueueEntries

Removes only successful keys whose current IDs equal the attempted IDs; preserves newer watcher events.

- Source: [MiraQueue.ps1:2312](../../MiraQueue.ps1#L2312)
- Parameters: `AttemptedEntries`, `SuccessfulKeys`.
- Direct internal calls: `Enter-QueueMutex`, `Exit-QueueMutex`, `Get-QueueDictionary`, `Get-QueueEntryKey`, `Read-QueueEntriesUnlocked`, `Write-Log`, `Write-QueueEntriesUnlocked`.

### Clear-PendingQueue

Shows queue counts and requests an explicit clear while preserving source and destination files.

- Source: [MiraQueue.ps1:2330](../../MiraQueue.ps1#L2330)
- Parameters: none.
- Direct internal calls: `Get-LatestQueueEntries`, `Read-EnterOrEsc`, `Read-QueueEntries`, `Request-ClearPendingQueue`, `Show-Header`, `Wait-Back`, `Write-Color`.

### Request-ClearPendingQueue

Explicitly discards work up to a timestamp cutoff and writes a watcher acknowledgment request.

- Source: [MiraQueue.ps1:2345](../../MiraQueue.ps1#L2345)
- Parameters: none.
- Direct internal calls: `ConvertTo-UtcTimestamp`, `Enter-QueueMutex`, `Exit-QueueMutex`, `Read-QueueEntriesUnlocked`, `Write-AtomicText`, `Write-QueueEntriesUnlocked`.

### Add-PendingEvent

Merges an event into the in-memory debounce buffer and schedules its commit time.

- Source: [MiraQueue.ps1:2361](../../MiraQueue.ps1#L2361)
- Parameters: `Entry`.
- Direct internal calls: `ConvertTo-QueueV2Entry`, `Get-QueueEntryKey`, `Merge-QueueEntryState`.

### Normalize-QueueRelPath

Normalizes separators and rejects traversal, rooted paths, alternate streams and ambiguous Windows path segments.

- Source: [MiraQueue.ps1:2381](../../MiraQueue.ps1#L2381)
- Parameters: `RelPath`.
- Direct internal calls: none.

### Get-QueueEntryKey

Combines pair name and validated relative path into a case-insensitive queue identity.

- Source: [MiraQueue.ps1:2391](../../MiraQueue.ps1#L2391)
- Parameters: `Entry`.
- Direct internal calls: `Normalize-QueueRelPath`.

### Test-QueueEntryChildOf

Checks whether an entry is a strict descendant of another entry in the same pair.

- Source: [MiraQueue.ps1:2396](../../MiraQueue.ps1#L2396)
- Parameters: `Entry`, `Parent`.
- Direct internal calls: `Normalize-QueueRelPath`.

### Flush-PendingEvents

Commits due buffered events and removes them from memory only after a successful queue write.

- Source: [MiraQueue.ps1:2409](../../MiraQueue.ps1#L2409)
- Parameters: none.
- Direct internal calls: `Merge-QueueEntriesToDisk`, `Write-Log`.

### Process-ClearQueueRequest

Clears buffered/disk work up to the saved cutoff while preserving newer events, then removes the request.

- Source: [MiraQueue.ps1:2426](../../MiraQueue.ps1#L2426)
- Parameters: none.
- Direct internal calls: `ConvertTo-UtcTimestamp`, `Enter-QueueMutex`, `Exit-QueueMutex`, `Read-QueueEntriesUnlocked`, `Remove-OwnedPath`, `Write-QueueEntriesUnlocked`.

### Merge-ReconciledDirectorySnapshotBatch

Commits child entries only if the restored directory's parent ID/action still matches.

- Source: [MiraQueue.ps1:2442](../../MiraQueue.ps1#L2442)
- Parameters: `RootEntry`, `ExpectedRootId`, `Entries`.
- Direct internal calls: `Enter-QueueMutex`, `Exit-QueueMutex`, `Get-QueueDictionary`, `Get-QueueEntryKey`, `Merge-QueueEntryState`, `Read-QueueEntriesUnlocked`, `Write-Log`, `Write-QueueEntriesUnlocked`.

### Queue-DirectorySnapshot

Queues safe child batches up to the configured limit, retaining the root tree job and logging truncation/errors.

- Source: [MiraQueue.ps1:2467](../../MiraQueue.ps1#L2467)
- Parameters: `Entry`, `SkipRootMerge`, `ExpectedRootId`.
- Direct internal calls: `Find-PairByName`, `Get-QueueEntryKey`, `Get-SafeTreeItems`, `Merge-QueueEntriesToDisk`, `Merge-ReconciledDirectorySnapshotBatch`, `New-QueueEntry`, `Test-Excluded`, `Write-Log`.

### Start-Watcher

Registers source-only filesystem events, enforces one watcher per queue identity and flushes/disposes resources on handled stop.

- Source: [MiraQueue.ps1:2518](../../MiraQueue.ps1#L2518)
- Parameters: none.
- Direct internal calls: `Assert-PairLayout`, `Flush-PendingEvents`, `Get-Pairs`, `Process-ClearQueueRequest`, `Process-WatcherEvent`, `Remove-OwnedPath`, `Resolve-DestinationPath`, `Show-Header`, `Wait-Back`, `Write-Color`, `Write-Log`.

### Process-WatcherEvent

Converts safe, nonexcluded source events to pending decisions and logs overflow/source errors for Full Mirror recovery.

- Source: [MiraQueue.ps1:2598](../../MiraQueue.ps1#L2598)
- Parameters: `Evt`.
- Direct internal calls: `Add-PendingEvent`, `Assert-NoReparsePath`, `Get-Pairs`, `New-QueueEntry`, `Queue-DirectorySnapshot`, `Test-Excluded`, `Test-PathInsideRoot`, `Write-Log`.

### Test-FileNeedsCopy

Compares source and destination file metadata to determine whether a copy is needed.

- Source: [MiraQueue.ps1:2691](../../MiraQueue.ps1#L2691)
- Parameters: `Source`, `Dest`, `SourceItem`.
- Direct internal calls: none.

### Copy-FileStreamWithProgress

Copies file bytes through streams while reporting transfer progress.

- Source: [MiraQueue.ps1:2709](../../MiraQueue.ps1#L2709)
- Parameters: `Source`, `Destination`, `ProgressCallback`, `SourceItem`.
- Direct internal calls: none.

### Copy-FileSafe

Copies a file with the configured replacement behavior and cleans its temporary resources.

- Source: [MiraQueue.ps1:2744](../../MiraQueue.ps1#L2744)
- Parameters: `Source`, `Dest`, `ProgressCallback`, `SourceItem`.
- Direct internal calls: `Assert-NoReparsePath`, `Copy-FileStreamWithProgress`, `Remove-OwnedPath`.

### Apply-OneEntry

Applies one currently validated item; destructive checks use current source/root state and uncertain work is retained.

- Source: [MiraQueue.ps1:2802](../../MiraQueue.ps1#L2802)
- Parameters: `Entry`, `ProgressCallback`, `DestinationOnline`, `PairOverride`, `MissingOnly`, `MirrorDelete`.
- Direct internal calls: `Copy-FileSafe`, `Find-PairByName`, `Get-ExactPathProbe`, `Get-SafeEntryPaths`, `Remove-VerifiedDestination`, `Resolve-DestinationPath`, `Test-DestRootAvailable`, `Test-Excluded`, `Test-FileNeedsCopy`.

### Get-ApplyProgressStartingStatus

Chooses DELETE, MKDIR or COPYING for an operation that is starting.

- Source: [MiraQueue.ps1:2878](../../MiraQueue.ps1#L2878)
- Parameters: `Entry`.
- Direct internal calls: none.

### Get-ApplyProgressFinalStatus

Maps an operation result to its final progress status.

- Source: [MiraQueue.ps1:2885](../../MiraQueue.ps1#L2885)
- Parameters: `Result`.
- Direct internal calls: none.

### Get-QueuePathDepth

Counts validated relative path segments for parent-before-child creation and child-before-parent deletion ordering.

- Source: [MiraQueue.ps1:2895](../../MiraQueue.ps1#L2895)
- Parameters: `RelPath`.
- Direct internal calls: `Normalize-QueueRelPath`.

### Get-DirectoryTransferTotalBytes

Measures included tree file bytes for grouped-job progress without following directory reparse points.

- Source: [MiraQueue.ps1:2902](../../MiraQueue.ps1#L2902)
- Parameters: `Entry`.
- Direct internal calls: `Find-PairByName`, `Format-ErrorSummary`, `Join-PathSafe`, `Test-Excluded`, `Write-Log`.

### Get-ApplyExecutionPlan

Groups directory upserts with their queued descendants and orders deletes, directory jobs and individual files.

- Source: [MiraQueue.ps1:2935](../../MiraQueue.ps1#L2935)
- Parameters: `Entries`.
- Direct internal calls: `Get-DirectoryTransferTotalBytes`, `Get-QueueEntryKey`, `Get-QueuePathDepth`, `Test-QueueEntryChildOf`.

### Remove-DirectoryTreeSafe

Allows removal only for a private staging-directory name, using the guarded .NET deletion helper.

- Source: [MiraQueue.ps1:2978](../../MiraQueue.ps1#L2978)
- Parameters: `Path`.
- Direct internal calls: `Remove-OwnedPath`.

### Get-DirectoryStagingPath

Constructs a sibling staging directory with a MiraQueue-specific name and random operation ID.

- Source: [MiraQueue.ps1:2984](../../MiraQueue.ps1#L2984)
- Parameters: `Destination`, `Id`.
- Direct internal calls: none.

### Build-DirectoryTreeRobocopyArgs

Builds nonpurging directory transport arguments with settings and source-root exclusion patterns.

- Source: [MiraQueue.ps1:2994](../../MiraQueue.ps1#L2994)
- Parameters: `Pair`, `Source`, `Destination`.
- Direct internal calls: `Convert-PairExcludeDirForRobocopy`, `Get-Array`, `Get-MapArray`.

### Invoke-StagedDirectoryMerge

Merges private staged content into an existing destination, preserving extras and applying configured metadata preferences.

- Source: [MiraQueue.ps1:3023](../../MiraQueue.ps1#L3023)
- Parameters: `StageRoot`, `DestinationRoot`.
- Direct internal calls: `Assert-NoReparsePath`, `Copy-FileSafe`, `Format-ErrorSummary`, `Get-QueuePathDepth`, `Get-RelativePath`, `Join-PathSafe`, `Test-FileNeedsCopy`.

### Invoke-NewDirectoryTreeCopy

Copies a validated directory into private staging with robocopy, publishes/merges on success and cleans staging/processes on failure.

- Source: [MiraQueue.ps1:3065](../../MiraQueue.ps1#L3065)
- Parameters: `Job`, `DestinationOnline`.
- Direct internal calls: `Build-DirectoryTreeRobocopyArgs`, `ConvertTo-ProcessArgumentString`, `Find-PairByName`, `Format-ErrorSummary`, `Get-DirectoryStagingPath`, `Get-QueueEntryKey`, `Get-SafeEntryPaths`, `Get-SafeTreeItems`, `Invoke-StagedDirectoryMerge`, `Join-PathSafe`, `Remove-DirectoryTreeSafe`, `Resolve-DestinationPath`, `Test-Excluded`, `Write-Log`.

### Invoke-ParallelFileTransfers

Runs bounded file workers, serializes conflicting targets, reports progress and cleans streams/temp files/runspaces.

- Source: [MiraQueue.ps1:3138](../../MiraQueue.ps1#L3138)
- Parameters: `Entries`, `PairOnline`, `ProgressTable`, `EntryIndexes`, `PairOverride`, `MissingOnly`.
- Direct internal calls: `Apply-OneEntry`, `Find-PairByName`, `Format-ErrorSummary`, `Get-ApplyEntryTotalBytes`, `Get-ApplyProgressFinalStatus`, `Get-PhysicalDestinationKey`, `Get-QueueEntryKey`, `Get-SafeEntryPaths`, `Join-PathSafe`, `Resolve-DestinationPath`, `Test-Excluded`, `Update-ApplyProgressRow`, `Write-Log`.

### Invoke-ApplyPending

Holds the apply lock, refreshes current work, executes the plan and acknowledges matching successes only.

- Source: [MiraQueue.ps1:3360](../../MiraQueue.ps1#L3360)
- Parameters: `Quiet`, `Snapshot`.
- Direct internal calls: `Apply-OneEntry`, `Enter-ApplyLock`, `Exit-ApplyLock`, `Get-ApplyEntryTotalBytes`, `Get-ApplyExecutionPlan`, `Get-ApplyProgressFinalStatus`, `Get-ApplyProgressStartingStatus`, `Get-QueueEntryKey`, `Invoke-NewDirectoryTreeCopy`, `Invoke-ParallelFileTransfers`, `New-ApplyProgressTable`, `Remove-AppliedQueueEntries`, `Show-ApplyResults`, `Show-Header`, `Sync-PendingSessionSnapshot`, `Update-ApplyProgressRow`, `Wait-Back`, `Write-Color`.

### Show-PendingPreview

Displays a read-only paged plan; Enter is a separate explicit apply action, Esc returns.

- Source: [MiraQueue.ps1:3462](../../MiraQueue.ps1#L3462)
- Parameters: `Snapshot`.
- Direct internal calls: `Get-ApplyExecutionPlan`, `Invoke-ApplyPending`, `Show-Header`, `Sync-PendingSessionSnapshot`, `Wait-Back`, `Write-Color`, `Write-PendingTable`.

### Get-DisplayAction

Maps queue action and baseline fields to ADD, UPDATE or DELETE for display.

- Source: [MiraQueue.ps1:3497](../../MiraQueue.ps1#L3497)
- Parameters: `Entry`.
- Direct internal calls: none.

### Test-ApplyResultVisible

Keeps failures visible while hiding harmless already-existing or already-missing results.

- Source: [MiraQueue.ps1:3504](../../MiraQueue.ps1#L3504)
- Parameters: `Result`.
- Direct internal calls: none.

### Write-PendingTable

Renders pending entries with their pair, action, kind and relative path.

- Source: [MiraQueue.ps1:3513](../../MiraQueue.ps1#L3513)
- Parameters: `Items`, `StartIndex`, `TotalCount`.
- Direct internal calls: `Center-Text`, `Fit-Cell`, `Get-DisplayAction`, `Write-Color`.

### Show-ApplyResults

Displays apply counts and individual operation results.

- Source: [MiraQueue.ps1:3543](../../MiraQueue.ps1#L3543)
- Parameters: `Results`, `Title`, `Compact`.
- Direct internal calls: `Center-Text`, `Fit-Cell`, `Show-Header`, `Test-ApplyResultVisible`, `Wait-Back`, `Write-Color`.

### New-InternalMirrorScanResult

Calculates display counts and detail text from internally discovered changes, independent of localized tool output.

- Source: [MiraQueue.ps1:3653](../../MiraQueue.ps1#L3653)
- Parameters: `FileChanges`.
- Direct internal calls: none.

### Get-InternalMirrorScan

Indexes safe source/destination trees with exclusions and terminating errors to derive the selected Full Mirror policy plan.

- Source: [MiraQueue.ps1:3691](../../MiraQueue.ps1#L3691)
- Parameters: `Pair`, `Policy`, `ProgressCallback`.
- Direct internal calls: `Assert-PairLayout`, `Get-ExactPathProbe`, `Get-RelativePath`, `Get-SafeTreeItems`, `New-InternalMirrorScanResult`, `Resolve-DestinationPath`, `Test-DestRootAvailable`, `Test-FileNeedsCopy`.

### ConvertTo-ProcessArgumentString

Quotes Windows process arguments, including embedded quotes and trailing backslashes.

- Source: [MiraQueue.ps1:3729](../../MiraQueue.ps1#L3729)
- Parameters: `Arguments`.
- Direct internal calls: none.

### Invoke-ApplyFileChanges

Applies only planned paths with current validation; Strict deletion and missing-only publication enforce their policy at execution.

- Source: [MiraQueue.ps1:3745](../../MiraQueue.ps1#L3745)
- Parameters: `Pair`, `FileChanges`, `Policy`.
- Direct internal calls: `Apply-OneEntry`, `Get-QueuePathDepth`, `Invoke-ParallelFileTransfers`, `Test-DestRootAvailable`.

### Test-PathInsideRoot

Checks whether a path lies within the specified root boundary.

- Source: [MiraQueue.ps1:3772](../../MiraQueue.ps1#L3772)
- Parameters: `Root`, `Path`.
- Direct internal calls: none.

### Invoke-FullMirrorApplyResults

Applies changed valid pair plans, reports scan/apply errors and always preserves the watcher queue.

- Source: [MiraQueue.ps1:3789](../../MiraQueue.ps1#L3789)
- Parameters: `Pairs`, `PreviewResults`, `Policy`.
- Direct internal calls: `Invoke-ApplyFileChanges`, `Show-ApplyResults`, `Wait-Back`, `Write-Color`, `Write-Log`.

### Invoke-FullMirror

Runs the whole-tree mirror workflow by collecting policy and preview/apply choice, then delegating pair processing.

- Source: [MiraQueue.ps1:3807](../../MiraQueue.ps1#L3807)
- Parameters: none.
- Direct internal calls: `Enter-ApplyLock`, `Exit-ApplyLock`, `Get-Pairs`, `Get-PolicyLabel`, `Invoke-FullMirrorApplyResults`, `Invoke-FullMirrorScan`, `Read-EnterOrEsc`, `Read-KeyChoice`, `Show-Header`, `Show-RobocopyResults`, `Test-AllDriveMapsOnline`, `Wait-Back`, `Write-Color`.

### Get-PolicyLabel

Returns the display name for a Full Mirror policy.

- Source: [MiraQueue.ps1:3888](../../MiraQueue.ps1#L3888)
- Parameters: `Policy`.
- Direct internal calls: none.

### Get-PolicyShort

Returns the compact table label for a Full Mirror policy.

- Source: [MiraQueue.ps1:3895](../../MiraQueue.ps1#L3895)
- Parameters: `Policy`.
- Direct internal calls: none.

### New-FullMirrorErrorResult

Creates a visible failed scan result with no actionable partial change list.

- Source: [MiraQueue.ps1:3910](../../MiraQueue.ps1#L3910)
- Parameters: `Pair`, `Preview`, `Policy`, `Status`, `Message`.
- Direct internal calls: `Get-PolicyShort`.

### Invoke-FullMirrorScan

Runs bounded isolated scan runspaces and reports per-pair results/errors, disposing workers in finally.

- Source: [MiraQueue.ps1:3918](../../MiraQueue.ps1#L3918)
- Parameters: `Pairs`, `Preview`, `Policy`.
- Direct internal calls: `Get-InternalMirrorScan`, `Get-PolicyShort`, `New-FullMirrorErrorResult`.

### Show-RobocopyResults

Displays Full Mirror pair summaries and detailed changes.

- Source: [MiraQueue.ps1:3961](../../MiraQueue.ps1#L3961)
- Parameters: `Results`, `Title`, `Pause`.
- Direct internal calls: `Center-Text`, `Fit-Cell`, `Show-Header`, `Wait-Back`, `Write-Color`.

### Show-Status

Displays configuration, watcher, queue and destination status.

- Source: [MiraQueue.ps1:4053](../../MiraQueue.ps1#L4053)
- Parameters: none.
- Direct internal calls: `Get-LatestQueueEntries`, `Get-OwnedScheduledTask`, `Get-Pairs`, `Get-WatcherProcesses`, `Read-QueueEntries`, `Resolve-DestinationPath`, `Show-Header`, `Test-DestRootAvailableFast`, `Wait-Back`, `Write-Color`.

### Show-Pairs

Lists configured source/destination pairs.

- Source: [MiraQueue.ps1:4082](../../MiraQueue.ps1#L4082)
- Parameters: none.
- Direct internal calls: `Get-Pairs`, `Write-Color`.

### Manage-PathsMenu

Presents the add, edit and remove pair actions.

- Source: [MiraQueue.ps1:4096](../../MiraQueue.ps1#L4096)
- Parameters: none.
- Direct internal calls: `Add-Pair`, `Edit-Pair`, `Read-KeyChoice`, `Remove-Pair`, `Show-Header`, `Show-Pairs`, `Write-Color`.

### Add-Pair

Prompts for source and destination paths, validates them and saves a new pair.

- Source: [MiraQueue.ps1:4116](../../MiraQueue.ps1#L4116)
- Parameters: none.
- Direct internal calls: `Assert-PairLayout`, `Get-AutoPairName`, `Get-Pairs`, `Normalize-PathText`, `Read-EnterOrEsc`, `Read-LineOrEsc`, `Save-Config`, `Set-MapArray`, `Set-Pairs`, `Show-Header`, `Show-SpinnerLine`, `Write-Color`.

### Select-PairIndex

Prompts the user to select a configured pair.

- Source: [MiraQueue.ps1:4147](../../MiraQueue.ps1#L4147)
- Parameters: none.
- Direct internal calls: `Get-Pairs`, `Read-NumberOrEsc`, `Show-Pairs`.

### Edit-Pair

Edits and saves the selected pair's source and destination paths.

- Source: [MiraQueue.ps1:4158](../../MiraQueue.ps1#L4158)
- Parameters: none.
- Direct internal calls: `Get-MapArray`, `Get-Pairs`, `Normalize-PathText`, `Read-LineOrEsc`, `Save-Config`, `Select-PairIndex`, `Set-MapArray`, `Set-Pairs`, `Show-Header`, `Write-Color`.

### Remove-Pair

Removes the selected pair from configuration after confirmation.

- Source: [MiraQueue.ps1:4182](../../MiraQueue.ps1#L4182)
- Parameters: none.
- Direct internal calls: `Get-Pairs`, `Read-EnterOrEsc`, `Save-Config`, `Select-PairIndex`, `Set-Pairs`, `Show-Header`, `Write-Color`.

### Add-SmartExclusion

Builds an exclusion from the selected path and scope.

- Source: [MiraQueue.ps1:4197](../../MiraQueue.ps1#L4197)
- Parameters: none.
- Direct internal calls: `Get-Array`, `Get-MapArray`, `Get-Pairs`, `Normalize-PathText`, `Read-LineOrEsc`, `Save-Config`, `Set-MapArray`, `Show-Header`, `Test-PathInsideRoot`, `Wait-Back`, `Write-Color`.

### Manage-ExclusionsMenu

Presents actions for viewing, adding and removing exclusions.

- Source: [MiraQueue.ps1:4256](../../MiraQueue.ps1#L4256)
- Parameters: none.
- Direct internal calls: `Add-GlobalExclusion`, `Add-PairExclusion`, `Add-SmartExclusion`, `Read-KeyChoice`, `Remove-Exclusion`, `Show-Exclusions`, `Show-Header`, `Wait-Back`, `Write-Color`.

### Add-GlobalExclusion

Adds and saves a global file or directory exclusion.

- Source: [MiraQueue.ps1:4289](../../MiraQueue.ps1#L4289)
- Parameters: `PropName`.
- Direct internal calls: `Get-Array`, `Read-LineOrEsc`, `Save-Config`, `Show-Header`.

### Add-PairExclusion

Adds and saves an exclusion for a selected pair.

- Source: [MiraQueue.ps1:4300](../../MiraQueue.ps1#L4300)
- Parameters: `MapName`.
- Direct internal calls: `Get-MapArray`, `Get-Pairs`, `Read-LineOrEsc`, `Save-Config`, `Select-PairIndex`, `Set-MapArray`, `Show-Header`.

### Get-ExclusionEntries

Collects global and per-pair exclusions for display and selection.

- Source: [MiraQueue.ps1:4315](../../MiraQueue.ps1#L4315)
- Parameters: none.
- Direct internal calls: `Get-Array`.

### Show-Exclusions

Displays configured exclusion entries.

- Source: [MiraQueue.ps1:4337](../../MiraQueue.ps1#L4337)
- Parameters: none.
- Direct internal calls: `Get-ExclusionEntries`, `Show-Header`, `Write-Color`.

### Remove-Exclusion

Removes the selected exclusion while protecting required defaults.

- Source: [MiraQueue.ps1:4351](../../MiraQueue.ps1#L4351)
- Parameters: none.
- Direct internal calls: `Get-Array`, `Get-ExclusionEntries`, `Get-MapArray`, `Read-NumberOrEsc`, `Save-Config`, `Set-MapArray`, `Show-Exclusions`, `Wait-Back`.

### SettingsMenu

Presents editable application settings and drive-map actions.

- Source: [MiraQueue.ps1:4375](../../MiraQueue.ps1#L4375)
- Parameters: none.
- Direct internal calls: `Manage-DriveMapsMenu`, `Read-KeyChoice`, `Set-IntSetting`, `Set-RangedIntSetting`, `Set-StringSetting`, `Show-Header`, `Toggle-BoolSetting`, `Write-Color`.

### Manage-DriveMapsMenu

Presents actions for viewing, editing and removing configured drive maps.

- Source: [MiraQueue.ps1:4407](../../MiraQueue.ps1#L4407)
- Parameters: none.
- Direct internal calls: `Add-OrUpdateDriveMap`, `Read-KeyChoice`, `Remove-DriveMap`, `Show-Header`, `Write-Color`.

### Add-OrUpdateDriveMap

Saves a drive-prefix substitution in the application configuration.

- Source: [MiraQueue.ps1:4433](../../MiraQueue.ps1#L4433)
- Parameters: none.
- Direct internal calls: `Read-LineOrEsc`, `Save-Config`, `Show-Header`.

### Remove-DriveMap

Removes a selected drive-prefix substitution from configuration.

- Source: [MiraQueue.ps1:4443](../../MiraQueue.ps1#L4443)
- Parameters: none.
- Direct internal calls: `Read-NumberOrEsc`, `Save-Config`, `Show-Header`, `Wait-Back`, `Write-Color`.

### Set-IntSetting

Prompts for, validates and saves a bounded integer setting.

- Source: [MiraQueue.ps1:4463](../../MiraQueue.ps1#L4463)
- Parameters: `Name`, `Min`.
- Direct internal calls: `Read-LineOrEsc`, `Save-Config`, `Show-Header`, `Wait-Back`, `Write-Color`.

### Set-RangedIntSetting

Edits an integer setting only within its supported inclusive range and saves configuration.

- Source: [MiraQueue.ps1:4478](../../MiraQueue.ps1#L4478)
- Parameters: `Name`, `Min`, `Max`.
- Direct internal calls: `Read-LineOrEsc`, `Save-Config`, `Show-Header`, `Wait-Back`, `Write-Color`.

### Set-StringSetting

Prompts for and saves a string setting.

- Source: [MiraQueue.ps1:4493](../../MiraQueue.ps1#L4493)
- Parameters: `Name`.
- Direct internal calls: `Initialize-App`, `Read-LineOrEsc`, `Save-Config`, `Show-Header`.

### Toggle-BoolSetting

Toggles and saves a Boolean setting.

- Source: [MiraQueue.ps1:4503](../../MiraQueue.ps1#L4503)
- Parameters: `Name`.
- Direct internal calls: `Save-Config`.

### Install-Required

Creates the scheduled watcher task after elevation checks and starts it so watch mode can run at logon.

- Source: [MiraQueue.ps1:4509](../../MiraQueue.ps1#L4509)
- Parameters: none.
- Direct internal calls: `Get-OwnedScheduledTask`, `Invoke-ElevatedMode`, `New-HiddenWatchLauncher`, `Remove-KnownScheduledTasks`, `Show-Header`, `Show-PostElevatedTaskStatus`, `Stop-KnownWatcherProcesses`, `Test-IsAdministrator`, `Test-OwnedScheduledTask`, `Wait-Back`, `Write-Color`, `Write-Log`.

### New-HiddenWatchLauncher

Writes a Unicode VBS helper that reads the Unicode script-directory pointer and starts hidden Watch mode.

- Source: [MiraQueue.ps1:4546](../../MiraQueue.ps1#L4546)
- Parameters: none.
- Direct internal calls: none.

### Test-RuntimePathProtected

Detects runtime/config paths inside configured source or destination trees so cleanup preserves them.

- Source: [MiraQueue.ps1:4561](../../MiraQueue.ps1#L4561)
- Parameters: `Path`.
- Direct internal calls: `Get-Pairs`, `Resolve-DestinationPath`, `Test-PathInsideRoot`.

### Remove-OwnedRuntimeData

Deletes exact runtime allowlisted files and owned log rotations, preserving unknown DataDir content.

- Source: [MiraQueue.ps1:4573](../../MiraQueue.ps1#L4573)
- Parameters: none.
- Direct internal calls: `Remove-OwnedPath`, `Test-PathInsideRoot`, `Test-RuntimePathProtected`.

### Uninstall-Everything

Confirms removal, stops the owned watcher, locks runtime storage and deletes only owned files; preserves backup content and user shortcuts.

- Source: [MiraQueue.ps1:4586](../../MiraQueue.ps1#L4586)
- Parameters: none.
- Direct internal calls: `Enter-ApplyLock`, `Enter-QueueMutex`, `Exit-ApplyLock`, `Exit-QueueMutex`, `Invoke-ElevatedMode`, `Read-EnterOrEsc`, `Remove-KnownScheduledTasks`, `Remove-OwnedPath`, `Remove-OwnedRuntimeData`, `Show-Header`, `Stop-KnownWatcherProcesses`, `Test-IsAdministrator`, `Test-RuntimePathProtected`, `Wait-Back`, `Write-Color`.

### Test-IsAdministrator

Checks whether the current Windows identity has administrator privileges.

- Source: [MiraQueue.ps1:4610](../../MiraQueue.ps1#L4610)
- Parameters: none.
- Direct internal calls: none.

### Invoke-ElevatedMode

Invokes elevated PowerShell directly with quoted arguments; avoids a shell-composed command string.

- Source: [MiraQueue.ps1:4620](../../MiraQueue.ps1#L4620)
- Parameters: `TargetMode`.
- Direct internal calls: `ConvertTo-ProcessArgumentString`, `Write-Color`.

### Show-PostElevatedTaskStatus

Displays the owned scheduled task's status after an elevated operation.

- Source: [MiraQueue.ps1:4629](../../MiraQueue.ps1#L4629)
- Parameters: `Operation`.
- Direct internal calls: `Get-OwnedScheduledTask`, `Get-WatcherProcesses`, `Write-Color`.

### Remove-KnownScheduledTasks

Unregisters only a task whose action matches this installation.

- Source: [MiraQueue.ps1:4659](../../MiraQueue.ps1#L4659)
- Parameters: `KeepTaskName`.
- Direct internal calls: `Get-OwnedScheduledTask`, `Write-Color`.

### InstallMenu

Presents watcher installation, restart and removal actions.

- Source: [MiraQueue.ps1:4670](../../MiraQueue.ps1#L4670)
- Parameters: none.
- Direct internal calls: `Install-Required`, `Read-KeyChoice`, `Remove-ScheduledWatcherOnly`, `Restart-ScheduledWatcher`, `Show-Header`, `Uninstall-Everything`, `Write-Color`.

### Restart-ScheduledWatcher

Restarts the owned scheduled watcher through the elevation helper.

- Source: [MiraQueue.ps1:4690](../../MiraQueue.ps1#L4690)
- Parameters: none.
- Direct internal calls: `Refresh-WatcherAfterConfigChange`, `Show-Header`, `Wait-Back`.

### Remove-ScheduledWatcherOnly

Stops and removes the owned watcher while preserving backup configuration and queue data.

- Source: [MiraQueue.ps1:4696](../../MiraQueue.ps1#L4696)
- Parameters: none.
- Direct internal calls: `Invoke-ElevatedMode`, `Remove-KnownScheduledTasks`, `Remove-OwnedPath`, `Show-Header`, `Show-PostElevatedTaskStatus`, `Stop-KnownWatcherProcesses`, `Test-IsAdministrator`, `Wait-Back`, `Write-Color`.

### Stop-KnownWatcherProcesses

Requests a graceful stop and waits for installation-specific watchers; refuses to kill a still-flushing process.

- Source: [MiraQueue.ps1:4716](../../MiraQueue.ps1#L4716)
- Parameters: none.
- Direct internal calls: `Get-WatcherProcesses`, `Write-AtomicText`.

### Get-WatcherProcesses

Matches PowerShell processes by exact -File installation path and -Mode Watch, excluding the current process.

- Source: [MiraQueue.ps1:4728](../../MiraQueue.ps1#L4728)
- Parameters: none.
- Direct internal calls: none.

### Test-OwnedScheduledTask

Checks the task's executable and exact generated launcher argument before any lifecycle mutation.

- Source: [MiraQueue.ps1:4737](../../MiraQueue.ps1#L4737)
- Parameters: `Task`.
- Direct internal calls: none.

### Get-OwnedScheduledTask

Locates the exact root-folder configured task only when its action belongs to this installation.

- Source: [MiraQueue.ps1:4745](../../MiraQueue.ps1#L4745)
- Parameters: `TaskName`.
- Direct internal calls: `Test-OwnedScheduledTask`.

### Test-AllDriveMapsOnline

Checks distinct destination roots and returns their combined availability and offline list.

- Source: [MiraQueue.ps1:4752](../../MiraQueue.ps1#L4752)
- Parameters: `Fast`.
- Direct internal calls: `Get-Pairs`, `Resolve-DestinationPath`, `Test-DestRootAvailableFast`.

### Show-MainMenu

Renders the main interactive command hub and routes user choices into the major workflows.

- Source: [MiraQueue.ps1:4773](../../MiraQueue.ps1#L4773)
- Parameters: none.
- Direct internal calls: `Clear-PendingQueue`, `Get-Pairs`, `Get-WatcherProcesses`, `InstallMenu`, `Invoke-ApplyPending`, `Invoke-FullMirror`, `Manage-ExclusionsMenu`, `Manage-PathsMenu`, `Read-KeyChoice`, `SettingsMenu`, `Show-Header`, `Show-PendingPreview`, `Show-Status`, `Sync-PendingSessionSnapshot`, `Wait-Back`, `Write-Color`, `Write-Log`.
