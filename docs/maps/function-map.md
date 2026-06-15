# Function Map

## Apply Pending

| Function | Lines | Role |
| --- | --- | --- |
| `Get-ApplyEntryTotalBytes` | 457-465 | Returns derived data for the apply pending workflow. |
| `Test-FileNeedsCopy` | 1382-1395 | Checks a safety, matching, availability, or selection condition. |
| `Copy-FileSafe` | 1429-1460 | Implements the copy  file safe helper used by the apply pending part of the script. |
| `Apply-OneEntry` | 1461-1503 | Implements the apply  one entry helper used by the apply pending part of the script. |
| `Test-ApplyResultSelectedForDisplay` | 1521-1529 | Checks a safety, matching, availability, or selection condition. |
| `Test-ApplyResultVisible` | 1693-1701 | Checks a safety, matching, availability, or selection condition. |
| `Show-ApplyResults` | 1729-1812 | Renders the  apply results screen or report. |
| `Invoke-RobocopyStreaming` | 2034-2120 | Handles the invoke  robocopy streaming step of the robocopy-based full mirror workflow. |
| `Invoke-ApplyFileChanges` | 2121-2199 | Implements the invoke  apply file changes helper used by the apply pending part of the script. |

## Configuration

| Function | Lines | Role |
| --- | --- | --- |
| `New-DefaultConfig` | 40-82 | Builds the V1.0.0 default settings object used on first run and during shape repair. |
| `Save-Config` | 83-94 | Implements the save  config helper used by the configuration part of the script. |
| `Refresh-WatcherAfterConfigChange` | 95-122 | Implements the refresh  watcher after config change helper used by the configuration part of the script. |
| `Ensure-ConfigShape` | 194-207 | Implements the ensure  config shape helper used by the configuration part of the script. |
| `Get-Array` | 208-216 | Returns derived data for the configuration workflow. |
| `Get-MapArray` | 227-235 | Returns derived data for the configuration workflow. |
| `Set-MapArray` | 236-245 | Updates config or script-scoped state for the configuration workflow. |
| `SettingsMenu` | 3095-3124 | Updates config or script-scoped state for the configuration workflow. |
| `Set-IntSetting` | 3181-3195 | Updates config or script-scoped state for the configuration workflow. |
| `Set-StringSetting` | 3196-3205 | Updates config or script-scoped state for the configuration workflow. |
| `Toggle-BoolSetting` | 3206-3211 | Implements the toggle  bool setting helper used by the configuration part of the script. |

## Console UI

| Function | Lines | Role |
| --- | --- | --- |
| `Write-Color` | 258-263 | Implements the write  color helper used by the console ui part of the script. |
| `Clear-Screen` | 293-296 | Implements the clear  screen helper used by the console ui part of the script. |
| `Fit-Cell` | 305-312 | Implements the fit  cell helper used by the console ui part of the script. |
| `Write-BoxHeader` | 313-327 | Implements the write  box header helper used by the console ui part of the script. |
| `Show-Header` | 328-334 | Renders the  header screen or report. |
| `Show-SpinnerLine` | 335-344 | Renders the  spinner line screen or report. |
| `Get-ConsoleWidthSafe` | 345-356 | Returns derived data for the console ui workflow. |
| `Format-ApplyProgressBar` | 388-398 | Supports apply-progress display by calculating, formatting, or redrawing progress state. |
| `Get-ApplyProgressLayout` | 399-456 | Supports apply-progress display by calculating, formatting, or redrawing progress state. |
| `Get-ApplyProgressPercent` | 466-474 | Supports apply-progress display by calculating, formatting, or redrawing progress state. |
| `Get-ApplyProgressSizeText` | 475-480 | Supports apply-progress display by calculating, formatting, or redrawing progress state. |
| `Get-ApplyProgressTiming` | 481-499 | Supports apply-progress display by calculating, formatting, or redrawing progress state. |
| `Get-ApplyStatusColor` | 500-522 | Returns derived data for the console ui workflow. |
| `Format-ApplyProgressRow` | 523-539 | Supports apply-progress display by calculating, formatting, or redrawing progress state. |
| `Write-ApplyProgressLine` | 540-545 | Supports apply-progress display by calculating, formatting, or redrawing progress state. |
| `Get-ApplyProgressBorder` | 546-552 | Supports apply-progress display by calculating, formatting, or redrawing progress state. |
| `Get-ApplyProgressHeaderRow` | 553-566 | Supports apply-progress display by calculating, formatting, or redrawing progress state. |
| `Get-ApplyProgressSummary` | 567-578 | Supports apply-progress display by calculating, formatting, or redrawing progress state. |
| `Get-ApplyProgressQueuedStatus` | 579-585 | Handles the get  apply progress queued status step of the NDJSON pending queue workflow. |
| `Test-ApplyProgressEntryVisible` | 586-592 | Supports apply-progress display by calculating, formatting, or redrawing progress state. |
| `New-ApplyProgressRow` | 593-609 | Supports apply-progress display by calculating, formatting, or redrawing progress state. |
| `Get-ApplyProgressVisibleCount` | 610-625 | Supports apply-progress display by calculating, formatting, or redrawing progress state. |
| `Get-ApplyProgressVisibleStart` | 626-638 | Supports apply-progress display by calculating, formatting, or redrawing progress state. |
| `Write-ApplyProgressAtLine` | 639-647 | Supports apply-progress display by calculating, formatting, or redrawing progress state. |
| `Redraw-ApplyProgressViewport` | 648-683 | Supports apply-progress display by calculating, formatting, or redrawing progress state. |
| `New-ApplyProgressTable` | 684-718 | Supports apply-progress display by calculating, formatting, or redrawing progress state. |
| `Add-ApplyProgressVisibleRow` | 719-736 | Supports apply-progress display by calculating, formatting, or redrawing progress state. |
| `Resolve-ApplyProgressRowIndex` | 737-753 | Supports apply-progress display by calculating, formatting, or redrawing progress state. |
| `Update-ApplyProgressRow` | 754-812 | Supports apply-progress display by calculating, formatting, or redrawing progress state. |
| `Wait-Back` | 813-820 | Implements the wait  back helper used by the console ui part of the script. |
| `Read-KeyChoice` | 821-832 | Reads console input with cancellation-safe behavior. |
| `Read-LineOrEsc` | 833-854 | Reads console input with cancellation-safe behavior. |
| `Read-NumberOrEsc` | 855-865 | Reads console input with cancellation-safe behavior. |
| `Read-EnterOrEsc` | 866-876 | Reads console input with cancellation-safe behavior. |
| `Copy-FileStreamWithProgress` | 1396-1428 | Supports apply-progress display by calculating, formatting, or redrawing progress state. |
| `Get-ApplyProgressStartingStatus` | 1504-1510 | Supports apply-progress display by calculating, formatting, or redrawing progress state. |
| `Get-ApplyProgressFinalStatus` | 1511-1520 | Supports apply-progress display by calculating, formatting, or redrawing progress state. |
| `Write-PendingTable` | 1702-1728 | Implements the write  pending table helper used by the console ui part of the script. |
| `Write-ScanProgress` | 1990-2010 | Supports apply-progress display by calculating, formatting, or redrawing progress state. |
| `Clear-ScanProgress` | 2024-2033 | Supports apply-progress display by calculating, formatting, or redrawing progress state. |

## Core helper

| Function | Lines | Role |
| --- | --- | --- |
| `Initialize-App` | 154-193 | Loads or creates the config file, resolves runtime paths, creates the data folder, and prepares queue and log paths. |
| `Write-Log` | 264-273 | Implements the write  log helper used by the core helper part of the script. |
| `Rotate-LogIfNeeded` | 274-292 | Implements the rotate  log if needed helper used by the core helper part of the script. |
| `Center-Text` | 297-304 | Implements the center  text helper used by the core helper part of the script. |
| `Format-ByteSize` | 357-372 | Implements the format  byte size helper used by the core helper part of the script. |
| `Format-ByteSpeed` | 373-378 | Implements the format  byte speed helper used by the core helper part of the script. |
| `Format-CompactDuration` | 379-387 | Implements the format  compact duration helper used by the core helper part of the script. |
| `Format-ErrorSummary` | 885-899 | Implements the format  error summary helper used by the core helper part of the script. |
| `Remove-OrphanedUpserts` | 1077-1098 | Removes a user-visible or runtime entry for the core helper workflow. |
| `Get-DisplayAction` | 1651-1662 | Returns derived data for the core helper workflow. |
| `New-HiddenWatchLauncher` | 3247-3261 | Implements the new  hidden watch launcher helper used by the core helper part of the script. |

## Full Mirror

| Function | Lines | Role |
| --- | --- | --- |
| `Build-RobocopyArgs` | 1813-1861 | Handles the build  robocopy args step of the robocopy-based full mirror workflow. |
| `Decode-RobocopyExit` | 1862-1869 | Handles the decode  robocopy exit step of the robocopy-based full mirror workflow. |
| `Get-RobocopySummary` | 1870-1898 | Handles the get  robocopy summary step of the robocopy-based full mirror workflow. |
| `Get-RobocopyChangeSummary` | 1899-1924 | Handles the get  robocopy change summary step of the robocopy-based full mirror workflow. |
| `Test-RobocopyChangeLine` | 1925-1930 | Handles the test  robocopy change line step of the robocopy-based full mirror workflow. |
| `Get-RobocopyChangeText` | 1931-1955 | Handles the get  robocopy change text step of the robocopy-based full mirror workflow. |
| `Convert-RobocopyLineToChange` | 1956-1989 | Handles the convert  robocopy line to change step of the robocopy-based full mirror workflow. |
| `Get-TempCleanupMinAgeMinutes` | 2200-2209 | Returns derived data for the full mirror workflow. |
| `Test-InternalTempCleanupFileName` | 2210-2215 | Checks a safety, matching, availability, or selection condition. |
| `Test-TempCleanupFileEligible` | 2229-2247 | Checks a safety, matching, availability, or selection condition. |
| `Invoke-TempCleanupChanges` | 2248-2271 | Implements the invoke  temp cleanup changes helper used by the full mirror part of the script. |
| `Invoke-FullMirror` | 2272-2370 | Runs the full mirror workflow, asks for policy and preview/apply choice, then delegates pair processing. |
| `Get-PolicyLabel` | 2371-2377 | Returns derived data for the full mirror workflow. |
| `Get-PolicyShort` | 2378-2384 | Returns derived data for the full mirror workflow. |
| `Show-RobocopyResults` | 2683-2774 | Handles the show  robocopy results step of the robocopy-based full mirror workflow. |

## Install and lifecycle

| Function | Lines | Role |
| --- | --- | --- |
| `Wait-ScheduledTaskNotRunning` | 123-137 | Implements the wait  scheduled task not running helper used by the install and lifecycle part of the script. |
| `ConvertTo-ProcessArgumentString` | 2011-2023 | Implements the convert to  process argument string helper used by the install and lifecycle part of the script. |
| `Install-Required` | 3212-3246 | Creates and starts the scheduled watcher task after elevation checks. |
| `Uninstall-Everything` | 3262-3323 | Removes scheduled task, runtime data, generated config, and shortcuts while preserving user source and destination folders. |
| `Test-IsAdministrator` | 3324-3333 | Checks a safety, matching, availability, or selection condition. |
| `Invoke-ElevatedMode` | 3334-3348 | Implements the invoke  elevated mode helper used by the install and lifecycle part of the script. |
| `Show-PostElevatedTaskStatus` | 3349-3378 | Renders the  post elevated task status screen or report. |
| `Remove-KnownScheduledTasks` | 3379-3394 | Removes a user-visible or runtime entry for the install and lifecycle workflow. |
| `InstallMenu` | 3395-3414 | Implements the install menu helper used by the install and lifecycle part of the script. |

## Menus and status

| Function | Lines | Role |
| --- | --- | --- |
| `Show-Status` | 2775-2803 | Renders the  status screen or report. |
| `Show-MainMenu` | 3484-3544 | Renders the  main menu screen or report. |

## Paths and filters

| Function | Lines | Role |
| --- | --- | --- |
| `Expand-TextPath` | 34-39 | Supports source, destination, pair, or relative path handling. |
| `Get-Pairs` | 217-220 | Supports source, destination, pair, or relative path handling. |
| `Set-Pairs` | 221-226 | Supports source, destination, pair, or relative path handling. |
| `Ensure-AllPairExclusionKeys` | 246-257 | Supports source, destination, pair, or relative path handling. |
| `Normalize-PathText` | 877-884 | Supports source, destination, pair, or relative path handling. |
| `Get-AutoPairName` | 900-919 | Supports source, destination, pair, or relative path handling. |
| `Resolve-DestinationPath` | 920-938 | Supports source, destination, pair, or relative path handling. |
| `Get-RelativePath` | 939-951 | Supports source, destination, pair, or relative path handling. |
| `Join-PathSafe` | 952-957 | Supports source, destination, pair, or relative path handling. |
| `Test-NameMatchesAny` | 958-966 | Checks a safety, matching, availability, or selection condition. |
| `Test-Excluded` | 967-990 | Checks a safety, matching, availability, or selection condition. |
| `Test-DestRootAvailable` | 991-1002 | Checks a safety, matching, availability, or selection condition. |
| `Find-PairByName` | 1003-1010 | Supports source, destination, pair, or relative path handling. |
| `Normalize-QueueRelPath` | 1154-1158 | Handles the normalize  queue rel path step of the NDJSON pending queue workflow. |
| `Get-QueueEntryDestinationPath` | 1676-1687 | Handles the get  queue entry destination path step of the NDJSON pending queue workflow. |
| `Test-PathInsideRoot` | 2216-2228 | Supports source, destination, pair, or relative path handling. |
| `Invoke-RobocopyForPairs` | 2385-2682 | Runs robocopy for valid pairs, parses output, and returns structured summaries. |
| `Show-Pairs` | 2804-2817 | Supports source, destination, pair, or relative path handling. |
| `Manage-PathsMenu` | 2818-2837 | Supports source, destination, pair, or relative path handling. |
| `Add-Pair` | 2838-2864 | Supports source, destination, pair, or relative path handling. |
| `Select-PairIndex` | 2865-2875 | Supports source, destination, pair, or relative path handling. |
| `Edit-Pair` | 2876-2901 | Supports source, destination, pair, or relative path handling. |
| `Remove-Pair` | 2902-2916 | Supports source, destination, pair, or relative path handling. |
| `Add-SmartExclusion` | 2917-2975 | Adds a user-visible or runtime entry for the paths and filters workflow. |
| `Manage-ExclusionsMenu` | 2976-3008 | Implements the manage  exclusions menu helper used by the paths and filters part of the script. |
| `Add-GlobalExclusion` | 3009-3019 | Adds a user-visible or runtime entry for the paths and filters workflow. |
| `Add-PairExclusion` | 3020-3034 | Supports source, destination, pair, or relative path handling. |
| `Get-ExclusionEntries` | 3035-3056 | Returns derived data for the paths and filters workflow. |
| `Show-Exclusions` | 3057-3070 | Renders the  exclusions screen or report. |
| `Remove-Exclusion` | 3071-3094 | Removes a user-visible or runtime entry for the paths and filters workflow. |
| `Manage-DriveMapsMenu` | 3125-3150 | Implements the manage  drive maps menu helper used by the paths and filters part of the script. |
| `Add-OrUpdateDriveMap` | 3151-3160 | Adds a user-visible or runtime entry for the paths and filters workflow. |
| `Remove-DriveMap` | 3161-3180 | Removes a user-visible or runtime entry for the paths and filters workflow. |
| `Test-AllDriveMapsOnline` | 3465-3483 | Checks a safety, matching, availability, or selection condition. |

## Queue model

| Function | Lines | Role |
| --- | --- | --- |
| `New-QueueEntry` | 1011-1041 | Handles the new  queue entry step of the NDJSON pending queue workflow. |
| `Append-QueueEntry` | 1042-1053 | Handles the append  queue entry step of the NDJSON pending queue workflow. |
| `Read-QueueEntries` | 1054-1065 | Handles the read  queue entries step of the NDJSON pending queue workflow. |
| `Get-LatestQueueEntries` | 1066-1076 | Handles the get  latest queue entries step of the NDJSON pending queue workflow. |
| `Write-QueueEntries` | 1099-1113 | Handles the write  queue entries step of the NDJSON pending queue workflow. |
| `Clear-PendingQueue` | 1114-1128 | Handles the clear  pending queue step of the NDJSON pending queue workflow. |
| `Request-ClearPendingQueue` | 1129-1146 | Handles the request  clear pending queue step of the NDJSON pending queue workflow. |
| `Add-PendingEvent` | 1147-1153 | Adds a user-visible or runtime entry for the queue model workflow. |
| `Get-QueueEntryKey` | 1159-1163 | Handles the get  queue entry key step of the NDJSON pending queue workflow. |
| `Test-QueueEntryChildOf` | 1164-1174 | Handles the test  queue entry child of step of the NDJSON pending queue workflow. |
| `Test-QueueEntryCoveredByAppliedDelete` | 1175-1182 | Handles the test  queue entry covered by applied delete step of the NDJSON pending queue workflow. |
| `Flush-PendingEvents` | 1183-1193 | Implements the flush  pending events helper used by the queue model part of the script. |
| `Process-ClearQueueRequest` | 1194-1205 | Handles the process  clear queue request step of the NDJSON pending queue workflow. |
| `Queue-DirectorySnapshot` | 1206-1227 | Handles the queue  directory snapshot step of the NDJSON pending queue workflow. |
| `Invoke-ApplyPending` | 1530-1619 | Applies the effective pending queue to configured destinations with progress reporting and queue cleanup. |
| `Show-PendingPreview` | 1620-1650 | Renders the  pending preview screen or report. |
| `Test-PendingPreviewEntryVisible` | 1663-1675 | Checks a safety, matching, availability, or selection condition. |
| `Get-VisiblePendingEntries` | 1688-1692 | Returns derived data for the queue model workflow. |

## Watcher

| Function | Lines | Role |
| --- | --- | --- |
| `Wait-ScheduledWatcherStarted` | 138-153 | Implements the wait  scheduled watcher started helper used by the watcher part of the script. |
| `Start-Watcher` | 1228-1292 | Starts source folder monitoring for configured pairs and queues file system events without copying files automatically. |
| `Process-WatcherEvent` | 1293-1381 | Translates created, changed, deleted, and renamed file system events into queue entries. |
| `Restart-ScheduledWatcher` | 3415-3420 | Implements the restart  scheduled watcher helper used by the watcher part of the script. |
| `Remove-ScheduledWatcherOnly` | 3421-3440 | Removes a user-visible or runtime entry for the watcher workflow. |
| `Stop-KnownWatcherProcesses` | 3441-3452 | Implements the stop  known watcher processes helper used by the watcher part of the script. |
| `Get-WatcherProcesses` | 3453-3464 | Returns derived data for the watcher workflow. |
