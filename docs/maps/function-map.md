# Function map — V2.0.0

The table follows source order. See the [complete reference](../explanation/15-function-reference.md) for parameter and dependency details.

| Function | Source line | Role |
| --- | ---: | --- |
| `Expand-TextPath` | [46](../../MiraQueue.ps1#L46) | Expands environment variables in user-facing paths before the rest of the script treats them as concrete filesystem locations. |
| `New-DefaultConfig` | [52](../../MiraQueue.ps1#L52) | Returns the neutral V2.0.0 defaults. Queue schema version is a separate contract. |
| `Write-AtomicText` | [96](../../MiraQueue.ps1#L96) | Writes a same-directory temporary UTF-8 file, atomically replaces the target and cleans the temporary file in finally. |
| `Save-Config` | [106](../../MiraQueue.ps1#L106) | Atomically persists validated configuration, invalidates the snapshot and refreshes the owned watcher. |
| `Refresh-WatcherAfterConfigChange` | [114](../../MiraQueue.ps1#L114) | Coordinates watcher restart after config edits so changed paths or settings are picked up without asking the user to find the process manually. |
| `Wait-ScheduledTaskNotRunning` | [142](../../MiraQueue.ps1#L142) | Polls the owned task until it stops or the retry limit is reached. |
| `Wait-ScheduledWatcherStarted` | [157](../../MiraQueue.ps1#L157) | Polls the owned task and watcher processes until startup is observed or the retry limit is reached. |
| `Initialize-App` | [173](../../MiraQueue.ps1#L173) | Loads config, validates runtime paths and initializes queue storage; ReadOnly skips file creation and migration. |
| `Ensure-ConfigShape` | [229](../../MiraQueue.ps1#L229) | Adds missing defaults while preserving user settings; validates identity/runtime fields and bounds file concurrency. |
| `Get-Array` | [266](../../MiraQueue.ps1#L266) | Normalizes null, scalar and collection values for array-based callers. |
| `Get-Pairs` | [275](../../MiraQueue.ps1#L275) | Returns the configured source/destination pairs. |
| `Set-Pairs` | [279](../../MiraQueue.ps1#L279) | Replaces the in-memory pair list and ensures its exclusion keys exist. |
| `Get-MapArray` | [285](../../MiraQueue.ps1#L285) | Reads an array from a named configuration map, returning an empty array for a missing key. |
| `Set-MapArray` | [294](../../MiraQueue.ps1#L294) | Creates or replaces an array entry in a named configuration map. |
| `Ensure-AllPairExclusionKeys` | [304](../../MiraQueue.ps1#L304) | Adds missing directory and file exclusion arrays for each configured pair. |
| `Write-Color` | [316](../../MiraQueue.ps1#L316) | Writes console text in the requested color, optionally without a newline. |
| `Write-Log` | [322](../../MiraQueue.ps1#L322) | Appends a timestamped log entry after rotation; logging failures do not interrupt file operations. |
| `Rotate-LogIfNeeded` | [332](../../MiraQueue.ps1#L332) | Rotates logs above 4 MiB and expires only timestamped rotations of this configured log basename. |
| `Clear-Screen` | [347](../../MiraQueue.ps1#L347) | Clears the console when the host supports it. |
| `Center-Text` | [351](../../MiraQueue.ps1#L351) | Pads text to center it within a requested width. |
| `Fit-Cell` | [359](../../MiraQueue.ps1#L359) | Truncates or pads text to fit a table column. |
| `Write-BoxHeader` | [367](../../MiraQueue.ps1#L367) | Renders a bordered title and optional subtitle. |
| `Show-Header` | [382](../../MiraQueue.ps1#L382) | Clears the screen and renders the application header. |
| `Show-SpinnerLine` | [389](../../MiraQueue.ps1#L389) | Updates a console spinner and its status message. |
| `Get-ConsoleWidthSafe` | [399](../../MiraQueue.ps1#L399) | Reads the console width with a fallback for hosts that do not expose it. |
| `Format-ByteSize` | [411](../../MiraQueue.ps1#L411) | Formats byte counts with a readable size unit. |
| `Format-ByteSpeed` | [427](../../MiraQueue.ps1#L427) | Formats transfer speed as a byte size per second. |
| `Format-CompactDuration` | [433](../../MiraQueue.ps1#L433) | Formats elapsed or remaining time for progress displays. |
| `Format-ApplyProgressBar` | [442](../../MiraQueue.ps1#L442) | Builds a fixed-width progress bar from a percentage. |
| `Get-ApplyProgressLayout` | [453](../../MiraQueue.ps1#L453) | Chooses progress column widths for the available console width. |
| `Get-ApplyEntryTotalBytes` | [515](../../MiraQueue.ps1#L515) | Returns the byte total for a file or grouped directory transfer. |
| `Get-ApplyProgressPercent` | [526](../../MiraQueue.ps1#L526) | Calculates the displayed completion percentage for a progress row. |
| `Get-ApplyProgressSizeText` | [535](../../MiraQueue.ps1#L535) | Formats copied and total byte counts for a progress row. |
| `Get-ApplyProgressTiming` | [541](../../MiraQueue.ps1#L541) | Calculates transfer speed and estimated remaining time for a progress row. |
| `Get-ApplyStatusColor` | [561](../../MiraQueue.ps1#L561) | Selects a console color for an apply status. |
| `Format-ApplyProgressRow` | [584](../../MiraQueue.ps1#L584) | Formats one progress row using the current column layout. |
| `Write-ApplyProgressLine` | [601](../../MiraQueue.ps1#L601) | Writes a progress line with its selected color. |
| `Get-ApplyProgressBorder` | [607](../../MiraQueue.ps1#L607) | Builds a border matching the progress table column widths. |
| `Get-ApplyProgressHeaderRow` | [614](../../MiraQueue.ps1#L614) | Builds the progress table column headings. |
| `Get-ApplyProgressSummary` | [628](../../MiraQueue.ps1#L628) | Summarizes overall progress across the transfer rows. |
| `Get-ApplyProgressQueuedStatus` | [640](../../MiraQueue.ps1#L640) | Selects the initial queued status for a transfer entry. |
| `Test-ApplyProgressEntryVisible` | [647](../../MiraQueue.ps1#L647) | Checks whether an entry belongs to the selected progress display set. |
| `New-ApplyProgressRow` | [654](../../MiraQueue.ps1#L654) | Creates the initial display state and byte counters for a transfer entry. |
| `Get-ApplyProgressVisibleCount` | [676](../../MiraQueue.ps1#L676) | Limits the number of visible progress rows to the available console height. |
| `Get-ApplyProgressVisibleStart` | [692](../../MiraQueue.ps1#L692) | Selects a viewport start that includes the current progress row. |
| `Write-ApplyProgressAtLine` | [712](../../MiraQueue.ps1#L712) | Writes progress text at a specified console line. |
| `Redraw-ApplyProgressViewport` | [721](../../MiraQueue.ps1#L721) | Redraws the visible progress rows and their table frame. |
| `New-ApplyProgressTable` | [757](../../MiraQueue.ps1#L757) | Initializes the progress table layout, rows and viewport state. |
| `Add-ApplyProgressVisibleRow` | [792](../../MiraQueue.ps1#L792) | Adds a transfer row to the progress display. |
| `Resolve-ApplyProgressRowIndex` | [810](../../MiraQueue.ps1#L810) | Finds the progress row corresponding to a transfer entry. |
| `Update-ApplyProgressRow` | [827](../../MiraQueue.ps1#L827) | Updates a transfer row's status, byte counters and rendered progress. |
| `Wait-Back` | [886](../../MiraQueue.ps1#L886) | Waits for the user to return from a console screen. |
| `Read-KeyChoice` | [894](../../MiraQueue.ps1#L894) | Collects r ea d k ey ch oi ce input from the console while preserving Escape/cancel behavior. |
| `Read-LineOrEsc` | [906](../../MiraQueue.ps1#L906) | Collects r ea d l in eo re sc input from the console while preserving Escape/cancel behavior. |
| `Read-NumberOrEsc` | [928](../../MiraQueue.ps1#L928) | Collects r ea d n um be ro re sc input from the console while preserving Escape/cancel behavior. |
| `Read-EnterOrEsc` | [939](../../MiraQueue.ps1#L939) | Collects r ea d e nt er or es c input from the console while preserving Escape/cancel behavior. |
| `Normalize-PathText` | [950](../../MiraQueue.ps1#L950) | Trims path quotes and whitespace, normalizes separators and removes non-root trailing separators. |
| `Format-ErrorSummary` | [958](../../MiraQueue.ps1#L958) | Maps an error message to a short display category. |
| `Get-AutoPairName` | [973](../../MiraQueue.ps1#L973) | Derives a pair name from a source or destination path. |
| `Resolve-DestinationPath` | [993](../../MiraQueue.ps1#L993) | Substitutes configured drive-map prefixes in destination paths. |
| `Get-RelativePath` | [1012](../../MiraQueue.ps1#L1012) | Returns a relative child path only after verifying a strict root boundary, including the separator. |
| `Join-PathSafe` | [1018](../../MiraQueue.ps1#L1018) | Validates a relative path and verifies that its canonical result remains strictly inside the supplied root. |
| `Assert-NoReparsePath` | [1027](../../MiraQueue.ps1#L1027) | Rejects reparse points or inspection errors on a path and its ancestors; missing future child paths are allowed. |
| `Assert-PairLayout` | [1042](../../MiraQueue.ps1#L1042) | Requires absolute nonoverlapping roots and prevents destinations from overlapping configured sources. |
| `Get-SafeEntryPaths` | [1059](../../MiraQueue.ps1#L1059) | Recomputes contained current paths, rejects reparse points and refuses queued work redirected by config edits. |
| `Get-SafeTreeItems` | [1074](../../MiraQueue.ps1#L1074) | Enumerates with terminating errors, prunes excluded subtrees and rejects encountered reparse points. |
| `Remove-OwnedPath` | [1091](../../MiraQueue.ps1#L1091) | Checks containment and reparse boundaries, clears ReadOnly when necessary, deletes with .NET and verifies absence. |
| `Remove-VerifiedDestination` | [1115](../../MiraQueue.ps1#L1115) | Checks exclusions throughout a directory, then reconfirms roots and source absence before deleting the target. |
| `Test-NameMatchesAny` | [1139](../../MiraQueue.ps1#L1139) | Checks a name against a collection of exclusion patterns. |
| `Test-RelativeDirExcluded` | [1148](../../MiraQueue.ps1#L1148) | Matches a normalized relative directory or descendant against a relative exclusion pattern. |
| `Convert-PairExcludeDirForRobocopy` | [1157](../../MiraQueue.ps1#L1157) | Resolves relative per-pair directory exclusions against the original source root for directory transport. |
| `Test-Excluded` | [1165](../../MiraQueue.ps1#L1165) | Checks global and per-pair exclusions for a relative file or directory path. |
| `Test-DestRootAvailable` | [1212](../../MiraQueue.ps1#L1212) | Checks destination root availability before operations that depend on it. |
| `Initialize-PhysicalPathApi` | [1224](../../MiraQueue.ps1#L1224) | Loads the small Windows native path-resolution interop type lazily. |
| `Get-PhysicalDestinationKey` | [1262](../../MiraQueue.ps1#L1262) | Resolves a destination ancestor for conflict serialization; uncertainty falls back to a shared serialization group. |
| `Test-TcpPortQuick` | [1288](../../MiraQueue.ps1#L1288) | Performs a bounded TCP readiness hint and closes the client; a positive hint is not deletion authorization. |
| `Test-DestRootAvailableFast` | [1311](../../MiraQueue.ps1#L1311) | Caches a short-lived root readiness hint for status displays. |
| `Enter-ApplyLock` | [1345](../../MiraQueue.ps1#L1345) | Acquires and holds an exclusive file handle for Apply, Full Mirror or uninstall; never steals a lock by age. |
| `Exit-ApplyLock` | [1365](../../MiraQueue.ps1#L1365) | Disposes this operation's lock handle; the reusable unlocked lock file remains until uninstall. |
| `Find-PairByName` | [1370](../../MiraQueue.ps1#L1370) | Finds a configured pair by its name. |
| `New-QueueEntry` | [1378](../../MiraQueue.ps1#L1378) | Creates a schema-2 source event with a stable random ID and explicit operation/event/baseline fields. |
| `ConvertTo-UtcTimestamp` | [1423](../../MiraQueue.ps1#L1423) | Normalizes string or DateTime JSON values to invariant UTC without losing subsecond precision; shared by queue writes and cutoff comparisons. |
| `ConvertTo-QueueV2Entry` | [1434](../../MiraQueue.ps1#L1434) | Validates and normalizes V1 or V2 records; preserves IDs and rejects invalid or unsupported schemas. |
| `Add-PendingMetric` | [1467](../../MiraQueue.ps1#L1467) | Accumulates optional elapsed times and counts globally and by pair/operation. |
| `Invoke-PendingPathProbe` | [1488](../../MiraQueue.ps1#L1488) | Wraps an exact path probe with optional performance attribution. |
| `Enter-QueueMutex` | [1495](../../MiraQueue.ps1#L1495) | Acquires the queue-path-specific mutex with timeout and abandoned-owner handling; returns null on acquisition failure. |
| `Exit-QueueMutex` | [1517](../../MiraQueue.ps1#L1517) | Releases/disposes the acquired mutex and records optional hold time. |
| `Read-QueueEntriesUnlocked` | [1527](../../MiraQueue.ps1#L1527) | Reads and validates every nonblank NDJSON record; throws on read/parse/schema failure instead of dropping work. |
| `Read-QueueEntries` | [1545](../../MiraQueue.ps1#L1545) | Acquires the queue mutex and returns validated records; timeout is an error, not an empty queue. |
| `Get-QueuePathNode` | [1551](../../MiraQueue.ps1#L1551) | Finds or creates a per-pair node in the transient hierarchical path index. |
| `Remove-QueueDescendants` | [1569](../../MiraQueue.ps1#L1569) | Removes relevant descendants through the index, or a small dictionary fallback, optionally only known-new work. |
| `Merge-QueueEntryState` | [1601](../../MiraQueue.ps1#L1601) | Reduces one normalized event into effective state while preserving baseline and parent/child semantics. |
| `Get-QueueDictionary` | [1640](../../MiraQueue.ps1#L1640) | Builds case-insensitive effective queue state with a shared path index for the batch. |
| `Get-LatestQueueEntries` | [1651](../../MiraQueue.ps1#L1651) | Returns indexed effective queue entries sorted for stable storage/display. |
| `Remove-OrphanedUpserts` | [1659](../../MiraQueue.ps1#L1659) | Filters upserts covered by a delete for the same path or an ancestor in the same pair. |
| `Write-QueueMetaUnlocked` | [1683](../../MiraQueue.ps1#L1683) | Atomically writes schema-2 counts and queue length/write-time fingerprint; caller holds the queue mutex. |
| `Get-QueueFileFingerprint` | [1708](../../MiraQueue.ps1#L1708) | Returns queue length and last-write ticks for in-process snapshot invalidation. |
| `Get-PendingPairIndex` | [1723](../../MiraQueue.ps1#L1723) | Indexes configured pairs and resolved roots for a scan, avoiding repeated pair/drive-map searches. |
| `Get-PendingDirectoryNames` | [1737](../../MiraQueue.ps1#L1737) | Enumerates requested names nonrecursively with a cap and early exit; partial absence never proves a missing item. |
| `Add-PendingDiscoveryAttribution` | [1768](../../MiraQueue.ps1#L1768) | Allocates shared directory-enumeration time across logical requests without double-counting physical totals. |
| `Resolve-PendingDestinationObservations` | [1783](../../MiraQueue.ps1#L1783) | Uses sparse exact probes or bounded dense enumeration; negative results require root confirmation. |
| `Get-PendingDestinationState` | [1865](../../MiraQueue.ps1#L1865) | Probes distinct roots and reports pair availability and observed root-state transitions. |
| `Save-PendingClassifications` | [1893](../../MiraQueue.ps1#L1893) | Commits changed upsert baselines only for matching IDs, capturing final entries/fingerprint under one lock. |
| `Get-ExactPathProbe` | [1931](../../MiraQueue.ps1#L1931) | Distinguishes Exists, Missing and Error using .NET attribute reads rather than treating all failures as absence. |
| `Sync-PendingDeleteEntries` | [1956](../../MiraQueue.ps1#L1956) | Reconciles restored sources and obsolete deletes; ReadOnly produces decisions in memory without queue writes. |
| `Queue-ReconciledDirectorySnapshot` | [2074](../../MiraQueue.ps1#L2074) | Rechecks a restored directory's ID/action before expanding its children. |
| `Sync-PendingSessionSnapshot` | [2097](../../MiraQueue.ps1#L2097) | Reuses stable observations, reconciles current work and reports counts; ReadOnly omits disk/log commits. |
| `Write-QueueEntriesUnlocked` | [2240](../../MiraQueue.ps1#L2240) | Atomically writes normalized NDJSON, then updates rebuildable metadata; never deletes the original as a fallback. |
| `Write-QueueEntries` | [2268](../../MiraQueue.ps1#L2268) | Serializes an explicit whole-queue replacement under the queue mutex and reports success. |
| `Test-QueueMetaFresh` | [2275](../../MiraQueue.ps1#L2275) | Checks metadata schema plus queue length/write ticks; metadata is a cache rather than pending-work authority. |
| `Initialize-QueueStorage` | [2284](../../MiraQueue.ps1#L2284) | Migrates/normalizes valid records under mutex when metadata is stale; invalid queues remain untouched. |
| `Merge-QueueEntriesToDisk` | [2299](../../MiraQueue.ps1#L2299) | Reads, reduces and writes a batch under one mutex so concurrent writer commits are not lost. |
| `Remove-AppliedQueueEntries` | [2312](../../MiraQueue.ps1#L2312) | Removes only successful keys whose current IDs equal the attempted IDs; preserves newer watcher events. |
| `Clear-PendingQueue` | [2330](../../MiraQueue.ps1#L2330) | Shows queue counts and requests an explicit clear while preserving source and destination files. |
| `Request-ClearPendingQueue` | [2345](../../MiraQueue.ps1#L2345) | Explicitly discards work up to a timestamp cutoff and writes a watcher acknowledgment request. |
| `Add-PendingEvent` | [2361](../../MiraQueue.ps1#L2361) | Merges an event into the in-memory debounce buffer and schedules its commit time. |
| `Normalize-QueueRelPath` | [2381](../../MiraQueue.ps1#L2381) | Normalizes separators and rejects traversal, rooted paths, alternate streams and ambiguous Windows path segments. |
| `Get-QueueEntryKey` | [2391](../../MiraQueue.ps1#L2391) | Combines pair name and validated relative path into a case-insensitive queue identity. |
| `Test-QueueEntryChildOf` | [2396](../../MiraQueue.ps1#L2396) | Checks whether an entry is a strict descendant of another entry in the same pair. |
| `Flush-PendingEvents` | [2409](../../MiraQueue.ps1#L2409) | Commits due buffered events and removes them from memory only after a successful queue write. |
| `Process-ClearQueueRequest` | [2426](../../MiraQueue.ps1#L2426) | Clears buffered/disk work up to the saved cutoff while preserving newer events, then removes the request. |
| `Merge-ReconciledDirectorySnapshotBatch` | [2442](../../MiraQueue.ps1#L2442) | Commits child entries only if the restored directory's parent ID/action still matches. |
| `Queue-DirectorySnapshot` | [2467](../../MiraQueue.ps1#L2467) | Queues safe child batches up to the configured limit, retaining the root tree job and logging truncation/errors. |
| `Start-Watcher` | [2518](../../MiraQueue.ps1#L2518) | Registers source-only filesystem events, enforces one watcher per queue identity and flushes/disposes resources on handled stop. |
| `Process-WatcherEvent` | [2598](../../MiraQueue.ps1#L2598) | Converts safe, nonexcluded source events to pending decisions and logs overflow/source errors for Full Mirror recovery. |
| `Test-FileNeedsCopy` | [2691](../../MiraQueue.ps1#L2691) | Compares source and destination file metadata to determine whether a copy is needed. |
| `Copy-FileStreamWithProgress` | [2709](../../MiraQueue.ps1#L2709) | Copies file bytes through streams while reporting transfer progress. |
| `Copy-FileSafe` | [2744](../../MiraQueue.ps1#L2744) | Copies a file with the configured replacement behavior and cleans its temporary resources. |
| `Apply-OneEntry` | [2802](../../MiraQueue.ps1#L2802) | Applies one currently validated item; destructive checks use current source/root state and uncertain work is retained. |
| `Get-ApplyProgressStartingStatus` | [2878](../../MiraQueue.ps1#L2878) | Chooses DELETE, MKDIR or COPYING for an operation that is starting. |
| `Get-ApplyProgressFinalStatus` | [2885](../../MiraQueue.ps1#L2885) | Maps an operation result to its final progress status. |
| `Get-QueuePathDepth` | [2895](../../MiraQueue.ps1#L2895) | Counts validated relative path segments for parent-before-child creation and child-before-parent deletion ordering. |
| `Get-DirectoryTransferTotalBytes` | [2902](../../MiraQueue.ps1#L2902) | Measures included tree file bytes for grouped-job progress without following directory reparse points. |
| `Get-ApplyExecutionPlan` | [2935](../../MiraQueue.ps1#L2935) | Groups directory upserts with their queued descendants and orders deletes, directory jobs and individual files. |
| `Remove-DirectoryTreeSafe` | [2978](../../MiraQueue.ps1#L2978) | Allows removal only for a private staging-directory name, using the guarded .NET deletion helper. |
| `Get-DirectoryStagingPath` | [2984](../../MiraQueue.ps1#L2984) | Constructs a sibling staging directory with a MiraQueue-specific name and random operation ID. |
| `Build-DirectoryTreeRobocopyArgs` | [2994](../../MiraQueue.ps1#L2994) | Builds nonpurging directory transport arguments with settings and source-root exclusion patterns. |
| `Invoke-StagedDirectoryMerge` | [3023](../../MiraQueue.ps1#L3023) | Merges private staged content into an existing destination, preserving extras and applying configured metadata preferences. |
| `Invoke-NewDirectoryTreeCopy` | [3065](../../MiraQueue.ps1#L3065) | Copies a validated directory into private staging with robocopy, publishes/merges on success and cleans staging/processes on failure. |
| `Invoke-ParallelFileTransfers` | [3138](../../MiraQueue.ps1#L3138) | Runs bounded file workers, serializes conflicting targets, reports progress and cleans streams/temp files/runspaces. |
| `Invoke-ApplyPending` | [3360](../../MiraQueue.ps1#L3360) | Holds the apply lock, refreshes current work, executes the plan and acknowledges matching successes only. |
| `Show-PendingPreview` | [3462](../../MiraQueue.ps1#L3462) | Displays a read-only paged plan; Enter is a separate explicit apply action, Esc returns. |
| `Get-DisplayAction` | [3497](../../MiraQueue.ps1#L3497) | Maps queue action and baseline fields to ADD, UPDATE or DELETE for display. |
| `Test-ApplyResultVisible` | [3504](../../MiraQueue.ps1#L3504) | Keeps failures visible while hiding harmless already-existing or already-missing results. |
| `Write-PendingTable` | [3513](../../MiraQueue.ps1#L3513) | Renders pending entries with their pair, action, kind and relative path. |
| `Show-ApplyResults` | [3543](../../MiraQueue.ps1#L3543) | Displays apply counts and individual operation results. |
| `New-InternalMirrorScanResult` | [3653](../../MiraQueue.ps1#L3653) | Calculates display counts and detail text from internally discovered changes, independent of localized tool output. |
| `Get-InternalMirrorScan` | [3691](../../MiraQueue.ps1#L3691) | Indexes safe source/destination trees with exclusions and terminating errors to derive the selected Full Mirror policy plan. |
| `ConvertTo-ProcessArgumentString` | [3729](../../MiraQueue.ps1#L3729) | Quotes Windows process arguments, including embedded quotes and trailing backslashes. |
| `Invoke-ApplyFileChanges` | [3745](../../MiraQueue.ps1#L3745) | Applies only planned paths with current validation; Strict deletion and missing-only publication enforce their policy at execution. |
| `Test-PathInsideRoot` | [3772](../../MiraQueue.ps1#L3772) | Checks whether a path lies within the specified root boundary. |
| `Invoke-FullMirrorApplyResults` | [3789](../../MiraQueue.ps1#L3789) | Applies changed valid pair plans, reports scan/apply errors and always preserves the watcher queue. |
| `Invoke-FullMirror` | [3807](../../MiraQueue.ps1#L3807) | Runs the whole-tree mirror workflow by collecting policy and preview/apply choice, then delegating pair processing. |
| `Get-PolicyLabel` | [3888](../../MiraQueue.ps1#L3888) | Returns the display name for a Full Mirror policy. |
| `Get-PolicyShort` | [3895](../../MiraQueue.ps1#L3895) | Returns the compact table label for a Full Mirror policy. |
| `New-FullMirrorErrorResult` | [3910](../../MiraQueue.ps1#L3910) | Creates a visible failed scan result with no actionable partial change list. |
| `Invoke-FullMirrorScan` | [3918](../../MiraQueue.ps1#L3918) | Runs bounded isolated scan runspaces and reports per-pair results/errors, disposing workers in finally. |
| `Show-RobocopyResults` | [3961](../../MiraQueue.ps1#L3961) | Displays Full Mirror pair summaries and detailed changes. |
| `Show-Status` | [4053](../../MiraQueue.ps1#L4053) | Displays configuration, watcher, queue and destination status. |
| `Show-Pairs` | [4082](../../MiraQueue.ps1#L4082) | Lists configured source/destination pairs. |
| `Manage-PathsMenu` | [4096](../../MiraQueue.ps1#L4096) | Presents the add, edit and remove pair actions. |
| `Add-Pair` | [4116](../../MiraQueue.ps1#L4116) | Prompts for source and destination paths, validates them and saves a new pair. |
| `Select-PairIndex` | [4147](../../MiraQueue.ps1#L4147) | Prompts the user to select a configured pair. |
| `Edit-Pair` | [4158](../../MiraQueue.ps1#L4158) | Edits and saves the selected pair's source and destination paths. |
| `Remove-Pair` | [4182](../../MiraQueue.ps1#L4182) | Removes the selected pair from configuration after confirmation. |
| `Add-SmartExclusion` | [4197](../../MiraQueue.ps1#L4197) | Builds an exclusion from the selected path and scope. |
| `Manage-ExclusionsMenu` | [4256](../../MiraQueue.ps1#L4256) | Presents actions for viewing, adding and removing exclusions. |
| `Add-GlobalExclusion` | [4289](../../MiraQueue.ps1#L4289) | Adds and saves a global file or directory exclusion. |
| `Add-PairExclusion` | [4300](../../MiraQueue.ps1#L4300) | Adds and saves an exclusion for a selected pair. |
| `Get-ExclusionEntries` | [4315](../../MiraQueue.ps1#L4315) | Collects global and per-pair exclusions for display and selection. |
| `Show-Exclusions` | [4337](../../MiraQueue.ps1#L4337) | Displays configured exclusion entries. |
| `Remove-Exclusion` | [4351](../../MiraQueue.ps1#L4351) | Removes the selected exclusion while protecting required defaults. |
| `SettingsMenu` | [4375](../../MiraQueue.ps1#L4375) | Presents editable application settings and drive-map actions. |
| `Manage-DriveMapsMenu` | [4407](../../MiraQueue.ps1#L4407) | Presents actions for viewing, editing and removing configured drive maps. |
| `Add-OrUpdateDriveMap` | [4433](../../MiraQueue.ps1#L4433) | Saves a drive-prefix substitution in the application configuration. |
| `Remove-DriveMap` | [4443](../../MiraQueue.ps1#L4443) | Removes a selected drive-prefix substitution from configuration. |
| `Set-IntSetting` | [4463](../../MiraQueue.ps1#L4463) | Prompts for, validates and saves a bounded integer setting. |
| `Set-RangedIntSetting` | [4478](../../MiraQueue.ps1#L4478) | Edits an integer setting only within its supported inclusive range and saves configuration. |
| `Set-StringSetting` | [4493](../../MiraQueue.ps1#L4493) | Prompts for and saves a string setting. |
| `Toggle-BoolSetting` | [4503](../../MiraQueue.ps1#L4503) | Toggles and saves a Boolean setting. |
| `Install-Required` | [4509](../../MiraQueue.ps1#L4509) | Creates the scheduled watcher task after elevation checks and starts it so watch mode can run at logon. |
| `New-HiddenWatchLauncher` | [4546](../../MiraQueue.ps1#L4546) | Writes a Unicode VBS helper that reads the Unicode script-directory pointer and starts hidden Watch mode. |
| `Test-RuntimePathProtected` | [4561](../../MiraQueue.ps1#L4561) | Detects runtime/config paths inside configured source or destination trees so cleanup preserves them. |
| `Remove-OwnedRuntimeData` | [4573](../../MiraQueue.ps1#L4573) | Deletes exact runtime allowlisted files and owned log rotations, preserving unknown DataDir content. |
| `Uninstall-Everything` | [4586](../../MiraQueue.ps1#L4586) | Confirms removal, stops the owned watcher, locks runtime storage and deletes only owned files; preserves backup content and user shortcuts. |
| `Test-IsAdministrator` | [4610](../../MiraQueue.ps1#L4610) | Checks whether the current Windows identity has administrator privileges. |
| `Invoke-ElevatedMode` | [4620](../../MiraQueue.ps1#L4620) | Invokes elevated PowerShell directly with quoted arguments; avoids a shell-composed command string. |
| `Show-PostElevatedTaskStatus` | [4629](../../MiraQueue.ps1#L4629) | Displays the owned scheduled task's status after an elevated operation. |
| `Remove-KnownScheduledTasks` | [4659](../../MiraQueue.ps1#L4659) | Unregisters only a task whose action matches this installation. |
| `InstallMenu` | [4670](../../MiraQueue.ps1#L4670) | Presents watcher installation, restart and removal actions. |
| `Restart-ScheduledWatcher` | [4690](../../MiraQueue.ps1#L4690) | Restarts the owned scheduled watcher through the elevation helper. |
| `Remove-ScheduledWatcherOnly` | [4696](../../MiraQueue.ps1#L4696) | Stops and removes the owned watcher while preserving backup configuration and queue data. |
| `Stop-KnownWatcherProcesses` | [4716](../../MiraQueue.ps1#L4716) | Requests a graceful stop and waits for installation-specific watchers; refuses to kill a still-flushing process. |
| `Get-WatcherProcesses` | [4728](../../MiraQueue.ps1#L4728) | Matches PowerShell processes by exact -File installation path and -Mode Watch, excluding the current process. |
| `Test-OwnedScheduledTask` | [4737](../../MiraQueue.ps1#L4737) | Checks the task's executable and exact generated launcher argument before any lifecycle mutation. |
| `Get-OwnedScheduledTask` | [4745](../../MiraQueue.ps1#L4745) | Locates the exact root-folder configured task only when its action belongs to this installation. |
| `Test-AllDriveMapsOnline` | [4752](../../MiraQueue.ps1#L4752) | Checks distinct destination roots and returns their combined availability and offline list. |
| `Show-MainMenu` | [4773](../../MiraQueue.ps1#L4773) | Renders the main interactive command hub and routes user choices into the major workflows. |
