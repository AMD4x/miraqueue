param(
    [ValidateSet("Menu","Watch","PreviewPending","ApplyPending","FullMirror","Status","Install","RemoveTask","Uninstall")]
    [string]$Mode = "Menu",
    [switch]$NoPause,
    [switch]$TracePendingPerformance
)

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

$ErrorActionPreference = "Stop"
$script:AppName = "MiraQueue 🪞"
$script:ProductVersion = "V2.0.0"
$script:DeveloperLine = "V2.0.0 - Developed by Ahmed Mustafa"
$script:ScriptPath = $PSCommandPath
if ([string]::IsNullOrWhiteSpace($script:ScriptPath)) { $script:ScriptPath = $MyInvocation.MyCommand.Path }
if ([string]::IsNullOrWhiteSpace($script:ScriptPath)) { $script:ScriptPath = Join-Path (Get-Location).Path "MiraQueue.ps1" }
$script:ScriptDir = Split-Path -Parent $script:ScriptPath
if ([string]::IsNullOrWhiteSpace($script:ScriptDir)) { $script:ScriptDir = (Get-Location).Path }

$script:ConfigPath = Join-Path $script:ScriptDir "MiraQueue.config.json"
$script:Config = $null
$script:DataDir = $null
$script:QueuePath = $null
$script:QueueMetaPath = $null
$script:QueueMutexName = $null
$script:LogPath = $null
$script:ApplyLockPath = $null
$script:ClearQueueRequestPath = $null
$script:HiddenWatchLauncherPath = $null
$script:ScriptDirPointerFile = $null
$script:StopWatcherRequestPath = $null
$script:Pending = @{}
$script:PendingSessionSnapshot = $null
$script:TracePendingPerformance = [bool]$TracePendingPerformance
$script:PendingPerformance = $null
$script:LastPendingPerformance = $null
$script:PendingScanActive = $false
$script:DriveStatusCache = @{}
$script:Mutex = $null
$script:ApplyLockStream = $null
$script:SuppressPause = [bool]$NoPause

function Expand-TextPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
    return [Environment]::ExpandEnvironmentVariables($Path)
}

function New-DefaultConfig {
    [ordered]@{
        Version = "V2.0.0"
        TaskName = "MiraQueue"
        DataDir = "%LOCALAPPDATA%\MiraQueue"
        QueueFile = "MiraQueue.queue.ndjson"
        LogFile = "MiraQueue.log"
        DebounceMs = 5000
        WatchBufferKB = 1024
        LogRetentionDays = 30
        PreserveModifiedTime = $true
        CopyAttributes = $false
        CopyTempThenReplace = $true
        DeleteDestOnSourceDelete = $true
        TimeToleranceSeconds = 2
        DirectoryScanMaxItems = 500000
        RobocopyThreads = 8
        RobocopyRetries = 1
        RobocopyWaitSeconds = 1
        RobocopyParallelBatches = 3
        ParallelFileTransfers = 4
        DriveMaps = [ordered]@{}
        Pairs = @()
        GlobalExcludeDirs = @(
            "System Volume Information",
            '$Recycle.Bin',
            "RECYCLER",
            "Recovery"
        )
        GlobalExcludeFiles = @(
            "Thumbs.db",
            "desktop.ini",
            "*.tmp",
            "*.crdownload",
            "*.part",
            "*.download",
            "*.mqtmp-*",
            "*.mqbackup-*"
        )
        PairExcludeDirs = [ordered]@{}
        PairExcludeFiles = [ordered]@{}
    }
}

function Write-AtomicText {
    param([string]$Path, [string]$Text)
    $temporary = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllText($temporary,$Text,[Text.UTF8Encoding]::new($true))
        if ([IO.File]::Exists($Path)) { [IO.File]::Replace($temporary,$Path,[System.Management.Automation.Language.NullString]::Value) }
        else { [IO.File]::Move($temporary,$Path) }
    } finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
}

function Save-Config {
    Ensure-ConfigShape
    Write-AtomicText $script:ConfigPath ($script:Config | ConvertTo-Json -Depth 50)
    $script:PendingSessionSnapshot = $null
    Write-Log 'INFO' 'Configuration saved'
    Refresh-WatcherAfterConfigChange
}

function Refresh-WatcherAfterConfigChange {
    try {
        $taskName = [string]$script:Config.TaskName
        $task = Get-OwnedScheduledTask -TaskName $taskName
        $watchers = @(Get-WatcherProcesses)
        if ($null -eq $task -and $watchers.Count -eq 0) { return }

        Stop-KnownWatcherProcesses

        if ($null -ne $task) {
            $task = Wait-ScheduledTaskNotRunning -TaskName $taskName
            Start-ScheduledTask -TaskName $taskName -ErrorAction Stop
            $updatedTask = Wait-ScheduledWatcherStarted -TaskName $taskName
            $watchers = @(Get-WatcherProcesses)
            if (($null -ne $updatedTask -and $updatedTask.State -eq "Running") -or $watchers.Count -gt 0) {
                $stateText = if ($null -ne $updatedTask) { [string]$updatedTask.State } else { "Unknown" }
                Write-Color ("Scheduled watcher restarted: " + $stateText + " (processes: " + $watchers.Count + ")") "Green"
            } else {
                $stateText = if ($null -ne $updatedTask) { [string]$updatedTask.State } else { "Not installed" }
                Write-Color ("Watcher restart requested, but it did not report Running yet. Current state: " + $stateText + " (processes: " + $watchers.Count + ")") "Yellow"
            }
        }
    } catch {
        Write-Color "Configuration saved. Restart the scheduled watcher from Install / Uninstall if new paths are not picked up." "Yellow"
        Write-Log "WARN" "Watcher refresh after config save failed: $($_.Exception.Message)"
    }
}

function Wait-ScheduledTaskNotRunning {
    param(
        [string]$TaskName,
        [int]$Attempts = 25,
        [int]$DelayMs = 200
    )
    $task = $null
    for ($i = 0; $i -lt $Attempts; $i++) {
        $task = Get-OwnedScheduledTask -TaskName $TaskName
        if ($null -eq $task -or $task.State -ne "Running") { return $task }
        Start-Sleep -Milliseconds $DelayMs
    }
    return (Get-OwnedScheduledTask -TaskName $TaskName)
}

function Wait-ScheduledWatcherStarted {
    param(
        [string]$TaskName,
        [int]$Attempts = 25,
        [int]$DelayMs = 200
    )
    $task = $null
    for ($i = 0; $i -lt $Attempts; $i++) {
        $task = Get-OwnedScheduledTask -TaskName $TaskName
        $watchers = @(Get-WatcherProcesses)
        if (($null -ne $task -and $task.State -eq "Running") -or $watchers.Count -gt 0) { return $task }
        Start-Sleep -Milliseconds $DelayMs
    }
    return (Get-OwnedScheduledTask -TaskName $TaskName)
}

function Initialize-App {
    param([switch]$ReadOnly)
    if (!(Test-Path -LiteralPath $script:ConfigPath)) {
        if ($ReadOnly) { throw "Configuration missing; start the menu once to configure MiraQueue" }
        $script:Config = [pscustomobject](New-DefaultConfig)
        $json = $script:Config | ConvertTo-Json -Depth 50
        Write-AtomicText $script:ConfigPath $json
    } else {
        try {
            $script:Config = Get-Content -LiteralPath $script:ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            Write-Host "Configuration file is invalid: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }

    Ensure-ConfigShape
    $script:DataDir = Expand-TextPath ([string]$script:Config.DataDir)
    if ([string]::IsNullOrWhiteSpace($script:DataDir)) {
        $script:DataDir = Join-Path $env:LOCALAPPDATA "MiraQueue"
    }
    $script:DataDir=[IO.Path]::GetFullPath($script:DataDir)
    if ($script:DataDir.TrimEnd('\') -ieq [IO.Path]::GetPathRoot($script:DataDir).TrimEnd('\')) { throw 'DataDir cannot be a filesystem root' }
    if (Test-RuntimePathProtected $script:DataDir) { throw 'DataDir must be outside configured source and destination trees' }
    Assert-NoReparsePath $script:DataDir
    if (-not $ReadOnly) { [IO.Directory]::CreateDirectory($script:DataDir) | Out-Null }
    $script:QueuePath = Join-Path $script:DataDir ([string]$script:Config.QueueFile)
    $script:QueueMetaPath = Join-Path $script:DataDir "MiraQueue.queue.meta.json"
    $mutexHash = [System.Security.Cryptography.SHA256]::Create()
    try {
        $mutexBytes = [System.Text.Encoding]::UTF8.GetBytes([IO.Path]::GetFullPath($script:QueuePath).ToUpperInvariant())
        $mutexId = ([System.BitConverter]::ToString($mutexHash.ComputeHash($mutexBytes))).Replace("-", "").Substring(0, 24)
    } finally {
        $mutexHash.Dispose()
    }
    $script:QueueMutexName = "Global\MiraQueueQueue_" + $mutexId
    $script:LogPath = Join-Path $script:DataDir ([string]$script:Config.LogFile)
    $script:ApplyLockPath = Join-Path $script:DataDir "MiraQueue.apply.lock"
    $script:ClearQueueRequestPath = Join-Path $script:DataDir "MiraQueue.clear-queue"
    $script:HiddenWatchLauncherPath = Join-Path $script:DataDir "MiraQueue.watch.hidden.vbs"
    $script:ScriptDirPointerFile = Join-Path $script:DataDir "MiraQueue.scriptdir.txt"
    $script:StopWatcherRequestPath = Join-Path $script:DataDir "MiraQueue.stop-watch"
    if ($ReadOnly) { return }
    Assert-NoReparsePath $script:DataDir
    [IO.File]::WriteAllText($script:ScriptDirPointerFile, $script:ScriptDir, [Text.Encoding]::Unicode)
    $mutex = Enter-QueueMutex
    if ($null -eq $mutex) { throw 'Queue initialization lock unavailable' }
    try {
        if (-not [IO.File]::Exists($script:QueuePath)) {
            $stream = [IO.File]::Open($script:QueuePath,[IO.FileMode]::CreateNew); $stream.Dispose()
        }
    } finally { Exit-QueueMutex $mutex }
    Initialize-QueueStorage
    Rotate-LogIfNeeded
}

function Ensure-ConfigShape {
    if ($script:Config -is [Collections.IDictionary]) { $script:Config = [pscustomobject]$script:Config }
    if ($null -eq $script:Config -or $script:Config -isnot [pscustomobject]) { throw 'Config must be a JSON object' }
    $defaults = New-DefaultConfig
    foreach ($prop in $defaults.Keys) {
        if ($null -eq $script:Config.PSObject.Properties[$prop]) {
            $script:Config | Add-Member -NotePropertyName $prop -NotePropertyValue $defaults[$prop] -Force
        }
    }
    if ($null -eq $script:Config.Pairs) { $script:Config.Pairs = @() }
    if ($null -eq $script:Config.DriveMaps) { $script:Config.DriveMaps = [pscustomobject]@{} }
    if ($script:Config.PairExcludeDirs -is [Collections.IDictionary]) { $script:Config.PairExcludeDirs=[pscustomobject]$script:Config.PairExcludeDirs }
    if ($script:Config.PairExcludeFiles -is [Collections.IDictionary]) { $script:Config.PairExcludeFiles=[pscustomobject]$script:Config.PairExcludeFiles }
    if ($script:Config.DriveMaps -is [Collections.IDictionary]) { $script:Config.DriveMaps=[pscustomobject]$script:Config.DriveMaps }
    if ($null -eq $script:Config.PairExcludeDirs) { $script:Config.PairExcludeDirs = [pscustomobject]@{} }
    if ($null -eq $script:Config.PairExcludeFiles) { $script:Config.PairExcludeFiles = [pscustomobject]@{} }
    $parallelFiles = 0
    if (-not [int]::TryParse([string]$script:Config.ParallelFileTransfers, [ref]$parallelFiles) -or $parallelFiles -lt 1 -or $parallelFiles -gt 32) {
        $script:Config.ParallelFileTransfers = 4
    }
    $names=@{}
    foreach ($pair in @(Get-Pairs)) {
        if ([string]::IsNullOrWhiteSpace([string]$pair.Name) -or [string]$pair.Name -match '[|\x00-\x1f]' -or $names.ContainsKey([string]$pair.Name)) { throw 'Pair names must be nonempty and unique (case-insensitive)' }
        $names[[string]$pair.Name]=$true
    }
    if ([string]::IsNullOrWhiteSpace([string]$script:Config.TaskName) -or [string]$script:Config.TaskName -match '[\\/*?"<>|]') { throw 'TaskName must be a plain task name' }
    if ([string]$script:Config.QueueFile -ieq [string]$script:Config.LogFile) { throw 'QueueFile and LogFile must be distinct' }
    $script:Config.Version = $script:ProductVersion
    foreach ($name in @('QueueFile','LogFile')) {
        $value = [string]$script:Config.$name
        $null = Normalize-QueueRelPath $value
        if ($value -in @("MiraQueue.queue.meta.json","MiraQueue.apply.lock","MiraQueue.clear-queue","MiraQueue.stop-watch","MiraQueue.watch.hidden.vbs","MiraQueue.scriptdir.txt")) { throw "Runtime filename is reserved: $value" }
        if ([string]::IsNullOrWhiteSpace($value) -or [IO.Path]::GetFileName($value) -cne $value -or $value -match '[:*?"<>|]') { throw "$name must be a filename inside DataDir" }
    }
    Ensure-AllPairExclusionKeys
}

function Get-Array {
    param([object]$Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [string]) { return @($Value) }
    if ($Value -is [System.Array]) { return @($Value) }
    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [pscustomobject])) { return @($Value) }
    return @($Value)
}

function Get-Pairs {
    return @(Get-Array $script:Config.Pairs)
}

function Set-Pairs {
    param([object[]]$Pairs)
    $script:Config | Add-Member -NotePropertyName "Pairs" -NotePropertyValue @($Pairs) -Force
    Ensure-AllPairExclusionKeys
}

function Get-MapArray {
    param([string]$MapName, [string]$Key)
    $map = $script:Config.PSObject.Properties[$MapName].Value
    if ($null -eq $map) { return @() }
    $prop = $map.PSObject.Properties[$Key]
    if ($null -eq $prop) { return @() }
    return @(Get-Array $prop.Value)
}

function Set-MapArray {
    param([string]$MapName, [string]$Key, [object[]]$Values)
    $map = $script:Config.PSObject.Properties[$MapName].Value
    if ($null -eq $map) {
        $map = [pscustomobject]@{}
        $script:Config | Add-Member -NotePropertyName $MapName -NotePropertyValue $map -Force
    }
    $map | Add-Member -NotePropertyName $Key -NotePropertyValue @($Values) -Force
}

function Ensure-AllPairExclusionKeys {
    foreach ($pair in Get-Pairs) {
        if ([string]::IsNullOrWhiteSpace([string]$pair.Name)) { continue }
        if ($null -eq $script:Config.PairExcludeDirs.PSObject.Properties[$pair.Name]) {
            Set-MapArray "PairExcludeDirs" ([string]$pair.Name) @()
        }
        if ($null -eq $script:Config.PairExcludeFiles.PSObject.Properties[$pair.Name]) {
            Set-MapArray "PairExcludeFiles" ([string]$pair.Name) @()
        }
    }
}

function Write-Color {
    param([string]$Text, [string]$Color = "Gray", [switch]$NoNewLine)
    if ($NoNewLine) { Write-Host -NoNewline $Text -ForegroundColor $Color }
    else { Write-Host $Text -ForegroundColor $Color }
}

function Write-Log {
    param([string]$Level, [string]$Message)
    try {
        if ([string]::IsNullOrWhiteSpace($script:LogPath)) { return }
        Rotate-LogIfNeeded
        $line = "{0} [{1}] {2}" -f (Get-Date).ToString("s"), $Level, $Message
        Add-Content -LiteralPath $script:LogPath -Value $line -Encoding UTF8
    } catch {}
}

function Rotate-LogIfNeeded {
    try {
        if ([string]::IsNullOrWhiteSpace($script:LogPath)) { return }
        $name = [regex]::Escape([IO.Path]::GetFileName($script:LogPath))
        foreach ($item in @(Get-ChildItem -LiteralPath $script:DataDir -File -Force -ErrorAction Stop)) {
            if ($item.Name -match ('^'+$name+'\.\d{8}-\d{6}\.old$') -and [int]$script:Config.LogRetentionDays -gt 0 -and $item.LastWriteTime -lt (Get-Date).AddDays(-[int]$script:Config.LogRetentionDays)) {
                Remove-OwnedPath $script:DataDir $item.FullName
            }
        }
        if ([IO.File]::Exists($script:LogPath) -and ([IO.FileInfo]::new($script:LogPath)).Length -gt 4194304) {
            [IO.File]::Move($script:LogPath, ($script:LogPath+'.'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.old'))
        }
    } catch { } # Logging must never replace the operation's error.
}

function Clear-Screen {
    try { Clear-Host -ErrorAction Stop } catch {}
}

function Center-Text {
    param([string]$Text, [int]$Width)
    if ($null -eq $Text) { $Text = "" }
    if ($Text.Length -ge $Width) { return $Text.Substring(0, $Width) }
    $left = [math]::Floor(($Width - $Text.Length) / 2)
    return (" " * $left) + $Text + (" " * ($Width - $Text.Length - $left))
}

function Fit-Cell {
    param([string]$Text, [int]$Width)
    if ($null -eq $Text) { $Text = "" }
    if ($Text.Length -le $Width) { return $Text + (" " * ($Width - $Text.Length)) }
    if ($Width -le 3) { return $Text.Substring(0, $Width) }
    return $Text.Substring(0, $Width - 3) + "..."
}

function Write-BoxHeader {
    param([string]$Title, [string]$Subtitle = "")
    $line = "=" * 72
    Write-Color ("+" + $line + "+") "DarkGray"
    Write-Color "| " "DarkGray" -NoNewLine
    Write-Color (Center-Text $Title 70) "Yellow" -NoNewLine
    Write-Color " |" "DarkGray"
    if (-not [string]::IsNullOrWhiteSpace($Subtitle)) {
        Write-Color "| " "DarkGray" -NoNewLine
        Write-Color (Center-Text $Subtitle 70) "DarkYellow" -NoNewLine
        Write-Color " |" "DarkGray"
    }
    Write-Color ("+" + $line + "+") "DarkGray"
}

function Show-Header {
    param([string]$Title = $script:AppName, [string]$Subtitle = $script:DeveloperLine)
    Clear-Screen
    Write-BoxHeader $Title $Subtitle
    Write-Host ""
}

function Show-SpinnerLine {
    param([string]$Text = "Working", [int]$Cycles = 8)
    $frames = @("|","/","-","\")
    for ($i = 0; $i -lt $Cycles; $i++) {
        Write-Host -NoNewline ("`r{0} {1}..." -f $frames[$i % $frames.Count], $Text) -ForegroundColor Yellow
        Start-Sleep -Milliseconds 55
    }
    Write-Host -NoNewline ("`r" + (" " * ($Text.Length + 8)) + "`r")
}

function Get-ConsoleWidthSafe {
    try {
        $width = [Console]::WindowWidth
        if ($width -ge 80) { return $width }
    } catch {}
    try {
        $width = $Host.UI.RawUI.WindowSize.Width
        if ($width -ge 80) { return $width }
    } catch {}
    return 120
}

function Format-ByteSize {
    param([Nullable[Int64]]$Bytes)
    if ($Bytes -eq $null) { return "--" }
    $value = [double]$Bytes
    if ($value -lt 0) { $value = 0 }
    $units = @("B", "KiB", "MiB", "GiB", "TiB")
    $idx = 0
    while ($value -ge 1024 -and $idx -lt ($units.Count - 1)) {
        $value = $value / 1024
        $idx++
    }
    if ($idx -eq 0) { return ("{0} {1}" -f [int64]$value, $units[$idx]) }
    if ($value -ge 100) { return ([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, "{0:0} {1}", $value, $units[$idx])) }
    return ([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, "{0:0.0} {1}", $value, $units[$idx]))
}

function Format-ByteSpeed {
    param([Nullable[Double]]$BytesPerSecond)
    if ($BytesPerSecond -eq $null -or [double]$BytesPerSecond -le 0) { return "--" }
    return ((Format-ByteSize ([int64][math]::Round([double]$BytesPerSecond))) + "/s")
}

function Format-CompactDuration {
    param([Nullable[Double]]$Seconds)
    if ($Seconds -eq $null -or [double]$Seconds -lt 0 -or [double]::IsInfinity([double]$Seconds) -or [double]::IsNaN([double]$Seconds)) { return "--" }
    $total = [int][math]::Ceiling([double]$Seconds)
    if ($total -lt 60) { return ("{0}s" -f $total) }
    if ($total -lt 3600) { return ("{0}m {1}s" -f [int]($total / 60), ($total % 60)) }
    return ("{0}h {1}m" -f [int]($total / 3600), [int](($total % 3600) / 60))
}

function Format-ApplyProgressBar {
    param([int]$Percent, [int]$Width)
    if ($Percent -lt 0) { $Percent = 0 }
    if ($Percent -gt 100) { $Percent = 100 }
    $barWidth = [math]::Max(8, $Width - 7)
    $filled = [int][math]::Floor(($Percent / 100.0) * $barWidth)
    if ($filled -gt $barWidth) { $filled = $barWidth }
    $empty = $barWidth - $filled
    return ("[{0}{1}] {2,3}%" -f ("#" * $filled), ("-" * $empty), $Percent)
}

function Get-ApplyProgressLayout {
    $width = [math]::Max(80, (Get-ConsoleWidthSafe) - 1)
    $cols = [ordered]@{ No=3; Status=7; Pair=12; Item=16; Progress=23; Size=23; Speed=10; Eta=7 }
    if ($width -ge 146) {
        $cols = [ordered]@{ No=3; Status=8; Pair=16; Item=30; Progress=30; Size=23; Speed=10; Eta=7 }
    } elseif ($width -lt 112) {
        $cols.Pair = 10
        $cols.Progress = 20
    } elseif ($width -lt 122) {
        $cols.Progress = 22
    }

    $overhead = 1 + ($cols.Count * 3)
    $fixedWidth = 0
    foreach ($name in $cols.Keys) {
        if ($name -ne "Item") { $fixedWidth += [int]$cols[$name] }
    }
    $itemWidth = $width - $overhead - $fixedWidth
    if ($itemWidth -lt 8) {
        $cols.Pair = 8
        $cols.Progress = 17
        $fixedWidth = 0
        foreach ($name in $cols.Keys) {
            if ($name -ne "Item") { $fixedWidth += [int]$cols[$name] }
        }
        $itemWidth = $width - $overhead - $fixedWidth
    }
    $cols.Item = [math]::Max(6, $itemWidth)

    $lineWidth = 1
    foreach ($col in $cols.Values) { $lineWidth += ([int]$col + 3) }
    while ($lineWidth -gt $width -and [int]$cols.Item -gt 6) {
        $cols.Item = [int]$cols.Item - 1
        $lineWidth--
    }
    while ($lineWidth -gt $width -and [int]$cols.Progress -gt 10) {
        $cols.Progress = [int]$cols.Progress - 1
        $lineWidth--
    }
    while ($lineWidth -gt $width -and [int]$cols.Pair -gt 4) {
        $cols.Pair = [int]$cols.Pair - 1
        $lineWidth--
    }
    while ($lineWidth -gt $width -and [int]$cols.Status -gt 4) {
        $cols.Status = [int]$cols.Status - 1
        $lineWidth--
    }
    while ($lineWidth -gt $width -and [int]$cols.Speed -gt 9) {
        $cols.Speed = [int]$cols.Speed - 1
        $lineWidth--
    }
    while ($lineWidth -gt $width -and [int]$cols.Size -gt 15) {
        $cols.Size = [int]$cols.Size - 1
        $lineWidth--
    }
    while ($lineWidth -gt $width -and [int]$cols.Eta -gt 4) {
        $cols.Eta = [int]$cols.Eta - 1
        $lineWidth--
    }
    return [pscustomobject]@{ Columns = $cols; LineWidth = $lineWidth }
}

function Get-ApplyEntryTotalBytes {
    param([object]$Entry)
    if ($null -eq $Entry -or $Entry.Action -eq "Delete") { return [int64]0 }
    try {
        if ($null -ne $Entry.PSObject.Properties["CoveredTotalBytes"]) { return [int64]$Entry.CoveredTotalBytes }
        if ([bool]$Entry.IsDirectory) { return [int64]0 }
        if ($Entry.Size -ne $null) { return [int64]$Entry.Size }
    } catch {}
    return [int64]0
}

function Get-ApplyProgressPercent {
    param([object]$Row)
    if ($Row.TotalBytes -gt 0) {
        return [int][math]::Floor(([double]$Row.CopiedBytes / [double]$Row.TotalBytes) * 100)
    }
    if ([bool]$Row.IsComplete -and ($Row.Status -eq "DONE" -or $Row.Status -eq "DELETE" -or $Row.Status -eq "MKDIR")) { return 100 }
    return 0
}

function Get-ApplyProgressSizeText {
    param([object]$Row)
    if (-not [bool]$Row.ShowsSize) { return "--" }
    return ((Format-ByteSize ([int64]$Row.CopiedBytes)) + " / " + (Format-ByteSize ([int64]$Row.TotalBytes)))
}

function Get-ApplyProgressTiming {
    param([object]$Row)
    if ($Row.Status -ne "COPYING" -or $null -eq $Row.StartedAt) {
        if (-not [bool]$Row.IsComplete -and ($Row.Status -eq "MKDIR" -or $Row.Status -eq "DELETE")) { return [pscustomobject]@{ Speed = "--"; Eta = "Waiting" } }
        switch ($Row.Status) {
            "WAITING" { return [pscustomobject]@{ Speed = "--"; Eta = "Waiting" } }
            "FAILED" { return [pscustomobject]@{ Speed = "--"; Eta = "Failed" } }
            "SKIPPED" { return [pscustomobject]@{ Speed = "--"; Eta = "Skipped" } }
            default { return [pscustomobject]@{ Speed = "--"; Eta = "Done" } }
        }
    }
    $startedUtc = ([datetime]$Row.StartedAt).ToUniversalTime()
    $elapsed = ([datetime]::UtcNow - $startedUtc).TotalSeconds
    if ($elapsed -le 0) { return [pscustomobject]@{ Speed = "--"; Eta = "--" } }
    $speed = [double]$Row.CopiedBytes / $elapsed
    $remaining = [math]::Max(0, [double]$Row.TotalBytes - [double]$Row.CopiedBytes)
    $eta = if ($speed -gt 0) { $remaining / $speed } else { $null }
    return [pscustomobject]@{ Speed = (Format-ByteSpeed $speed); Eta = (Format-CompactDuration $eta) }
}

function Get-ApplyStatusColor {
    param([object]$StatusOrRow)
    $status = [string]$StatusOrRow
    $isComplete = $true
    if ($null -ne $StatusOrRow -and $null -ne $StatusOrRow.PSObject.Properties["Status"]) {
        $status = [string]$StatusOrRow.Status
        if ($null -ne $StatusOrRow.PSObject.Properties["IsComplete"]) { $isComplete = [bool]$StatusOrRow.IsComplete }
    }
    if (-not $isComplete) {
        if ($status -eq "MKDIR" -or $status -eq "DELETE") { return "DarkYellow" }
        if ($status -eq "WAITING") { return "DarkGray" }
    }
    switch ($status) {
        "DONE" { return "Green" }
        "DELETE" { return "Red" }
        "MKDIR" { return "Green" }
        "COPYING" { return "Yellow" }
        "FAILED" { return "Red" }
        "SKIPPED" { return "DarkYellow" }
        default { return "DarkGray" }
    }
}

function Format-ApplyProgressRow {
    param([object]$Table, [object]$Row)
    $c = $Table.Layout.Columns
    $percent = Get-ApplyProgressPercent $Row
    $timing = Get-ApplyProgressTiming $Row
    $progress = Format-ApplyProgressBar -Percent $percent -Width ([int]$c.Progress)
    return ("| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} |" -f
        (Fit-Cell ([string]$Row.No) ([int]$c.No)),
        (Fit-Cell ([string]$Row.Status) ([int]$c.Status)),
        (Fit-Cell ([string]$Row.Pair) ([int]$c.Pair)),
        (Fit-Cell ([string]$Row.Item) ([int]$c.Item)),
        (Fit-Cell $progress ([int]$c.Progress)),
        (Fit-Cell (Get-ApplyProgressSizeText $Row) ([int]$c.Size)),
        (Fit-Cell ([string]$timing.Speed) ([int]$c.Speed)),
        (Fit-Cell ([string]$timing.Eta) ([int]$c.Eta)))
}

function Write-ApplyProgressLine {
    param([string]$Text, [string]$Color, [int]$Width)
    if ($Text.Length -gt $Width) { $Text = $Text.Substring(0, $Width) }
    Write-Color ($Text.PadRight($Width)) $Color
}

function Get-ApplyProgressBorder {
    param([object]$Layout)
    $line = "+"
    foreach ($col in $Layout.Columns.Values) { $line += ("-" * ([int]$col + 2)) + "+" }
    return $line
}

function Get-ApplyProgressHeaderRow {
    param([object]$Layout)
    $c = $Layout.Columns
    return ("| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} |" -f
        (Center-Text "#" ([int]$c.No)),
        (Center-Text "Status" ([int]$c.Status)),
        (Center-Text "Pair" ([int]$c.Pair)),
        (Center-Text "Item" ([int]$c.Item)),
        (Center-Text "Progress" ([int]$c.Progress)),
        (Center-Text "Size" ([int]$c.Size)),
        (Center-Text "Speed" ([int]$c.Speed)),
        (Center-Text "ETA" ([int]$c.Eta)))
}

function Get-ApplyProgressSummary {
    param([object]$Table)
    $done = @($Table.Rows | Where-Object { [bool]$_.IsComplete -and ($_.Status -eq "DONE" -or $_.Status -eq "DELETE" -or $_.Status -eq "MKDIR") }).Count
    $copying = @($Table.Rows | Where-Object { $_.Status -eq "COPYING" }).Count
    $waiting = @($Table.Rows | Where-Object { -not [bool]$_.IsComplete -and $_.Status -ne "COPYING" -and $_.Status -ne "FAILED" -and $_.Status -ne "SKIPPED" }).Count
    $skipped = @($Table.Rows | Where-Object { $_.Status -eq "SKIPPED" }).Count
    $failed = @($Table.Rows | Where-Object { $_.Status -eq "FAILED" }).Count
    $total = @($Table.Rows).Count
    $processed = @($Table.Rows | Where-Object { [bool]$_.IsComplete }).Count
    return ("Processed: {0}/{1}    Done: {2}    Copying: {3}    Waiting: {4}    Skipped: {5}    Failed: {6}" -f $processed, $total, $done, $copying, $waiting, $skipped, $failed)
}

function Get-ApplyProgressQueuedStatus {
    param([object]$Entry)
    if ($Entry.Action -eq "Delete") { return "DELETE" }
    if ([bool]$Entry.IsDirectory) { return "MKDIR" }
    return "WAITING"
}

function Test-ApplyProgressEntryVisible {
    param([object]$Entry, [hashtable]$VisibleEntryKeys = $null)
    if ($null -eq $VisibleEntryKeys) { return $true }
    if ($null -eq $Entry) { return $false }
    return $VisibleEntryKeys.ContainsKey((Get-QueueEntryKey $Entry))
}

function New-ApplyProgressRow {
    param([object]$Entry, [int]$No)
    $coveredCount = if ($null -ne $Entry.PSObject.Properties["CoveredCount"]) { [int]$Entry.CoveredCount } else { 0 }
    $hasCoveredSize = ($null -ne $Entry.PSObject.Properties["CoveredTotalBytes"])
    $hasFileSize = (-not [bool]$Entry.IsDirectory -and $Entry.Action -ne "Delete" -and $Entry.Size -ne $null)
    $totalBytes = Get-ApplyEntryTotalBytes $Entry
    $itemText = if ($coveredCount -gt 1) { "{0} [{1} items]" -f [string]$Entry.RelPath, $coveredCount } else { [string]$Entry.RelPath }
    return [pscustomobject]@{
        No = $No
        Status = Get-ApplyProgressQueuedStatus $Entry
        Pair = [string]$Entry.PairName
        Item = $itemText
        CopiedBytes = [int64]0
        TotalBytes = $totalBytes
        IsFileEntry = (-not [bool]$Entry.IsDirectory -and $Entry.Action -ne "Delete")
        ShowsSize = ($Entry.Action -ne "Delete" -and ($hasCoveredSize -or $hasFileSize))
        IsComplete = $false
        StartedAt = $null
        LastRender = [datetime]::MinValue
    }
}

function Get-ApplyProgressVisibleCount {
    param([int]$TotalRows)
    if ($TotalRows -le 0) { return 0 }
    $height = 30
    try {
        if ([Console]::WindowHeight -ge 12) { $height = [Console]::WindowHeight }
    } catch {
        try {
            if ($Host.UI.RawUI.WindowSize.Height -ge 12) { $height = $Host.UI.RawUI.WindowSize.Height }
        } catch {}
    }
    $count = [math]::Max(4, [math]::Min(12, $height - 12))
    if ($TotalRows -lt $count) { return [math]::Max(1, $TotalRows) }
    return $count
}

function Get-ApplyProgressVisibleStart {
    param([object]$Table, [int]$CurrentIndex)
    $total = @($Table.Rows).Count
    $count = [int]$Table.VisibleCount
    if ($total -le $count) { return 0 }
    if ($CurrentIndex -lt 0) { return 0 }

    $currentStart = [math]::Max(0, [int]$Table.VisibleStart)
    $currentEnd = $currentStart + $count - 1
    if ($CurrentIndex -ge $currentStart -and $CurrentIndex -le $currentEnd) {
        return $currentStart
    }

    $start = [int]([math]::Floor($CurrentIndex / [double]$count) * $count)
    $maxStart = $total - $count
    if ($start -gt $maxStart) { $start = $maxStart }
    if ($start -lt 0) { $start = 0 }
    return $start
}

function Write-ApplyProgressAtLine {
    param([int]$Line, [string]$Text, [string]$Color, [int]$Width)
    [Console]::SetCursorPosition(0, $Line)
    Write-Host -NoNewline (" " * $Width)
    [Console]::SetCursorPosition(0, $Line)
    if ($Text.Length -gt $Width) { $Text = $Text.Substring(0, $Width) }
    Write-Host -NoNewline ($Text.PadRight($Width)) -ForegroundColor $Color
}

function Redraw-ApplyProgressViewport {
    param([object]$Table, [switch]$Initial)
    $border = Get-ApplyProgressBorder $Table.Layout
    $lines = New-Object System.Collections.Generic.List[object]
    $lines.Add([pscustomobject]@{ Text=$border; Color="DarkGray" }) | Out-Null
    $lines.Add([pscustomobject]@{ Text=(Get-ApplyProgressHeaderRow $Table.Layout); Color="DarkGray" }) | Out-Null
    $lines.Add([pscustomobject]@{ Text=$border; Color="DarkGray" }) | Out-Null
    $rowCount = @($Table.Rows).Count
    if ($rowCount -gt 0 -and [int]$Table.VisibleCount -gt 0) {
        $last = [math]::Min($rowCount - 1, [int]$Table.VisibleStart + [int]$Table.VisibleCount - 1)
        for ($i = [int]$Table.VisibleStart; $i -le $last; $i++) {
            $row = $Table.Rows[$i]
            $lines.Add([pscustomobject]@{ Text=(Format-ApplyProgressRow -Table $Table -Row $row); Color=(Get-ApplyStatusColor $row) }) | Out-Null
        }
    }
    $lines.Add([pscustomobject]@{ Text=$border; Color="DarkGray" }) | Out-Null
    $lines.Add([pscustomobject]@{ Text=(Get-ApplyProgressSummary $Table); Color="DarkGray" }) | Out-Null

    if (-not $Table.Interactive) {
        if ($Initial) {
            foreach ($line in $lines) { Write-ApplyProgressLine $line.Text $line.Color $Table.Layout.LineWidth }
            Write-Host ""
        }
        return
    }

    try {
        for ($i = 0; $i -lt $lines.Count; $i++) {
            Write-ApplyProgressAtLine -Line ($Table.TopLine + $i) -Text $lines[$i].Text -Color $lines[$i].Color -Width $Table.Layout.LineWidth
        }
        [Console]::SetCursorPosition(0, $Table.AfterLine)
    } catch {
        $Table.Interactive = $false
    }
}

function New-ApplyProgressTable {
    param([object[]]$Entries, [hashtable]$VisibleEntryKeys = $null)
    $layout = Get-ApplyProgressLayout
    $rows = New-Object System.Collections.Generic.List[object]
    $entryRowIndexes = @{}
    for ($i = 0; $i -lt $Entries.Count; $i++) {
        $entry = $Entries[$i]
        if (Test-ApplyProgressEntryVisible -Entry $entry -VisibleEntryKeys $VisibleEntryKeys) {
            $entryRowIndexes[[string]$i] = $rows.Count
            $rows.Add((New-ApplyProgressRow -Entry $entry -No ($rows.Count + 1))) | Out-Null
        } else {
            $entryRowIndexes[[string]$i] = -1
        }
    }
    $interactive = $true
    try { if ([Console]::IsOutputRedirected) { $interactive = $false } } catch { $interactive = $false }
    try { $topLine = [Console]::CursorTop } catch { $topLine = 0; $interactive = $false }
    $visibleCount = Get-ApplyProgressVisibleCount -TotalRows $rows.Count
    $table = [pscustomobject]@{
        Layout = $layout
        Rows = @($rows.ToArray())
        Entries = @($Entries)
        EntryRowIndexes = $entryRowIndexes
        TopLine = $topLine
        VisibleStart = 0
        VisibleCount = $visibleCount
        CurrentIndex = -1
        SummaryLine = ($topLine + 4 + $visibleCount)
        AfterLine = ($topLine + 5 + $visibleCount)
        Interactive = $interactive
    }
    Redraw-ApplyProgressViewport -Table $table -Initial
    return $table
}

function Add-ApplyProgressVisibleRow {
    param([object]$Table, [int]$EntryIndex)
    if ($null -eq $Table) { return -1 }
    if ($null -eq $Table.PSObject.Properties["Entries"] -or $EntryIndex -lt 0 -or $EntryIndex -ge @($Table.Entries).Count) { return -1 }
    $entry = $Table.Entries[$EntryIndex]
    $rowIndex = @($Table.Rows).Count
    $newRow = New-ApplyProgressRow -Entry $entry -No ($rowIndex + 1)
    $Table.Rows = @($Table.Rows) + $newRow
    if ($null -ne $Table.PSObject.Properties["EntryRowIndexes"]) {
        $Table.EntryRowIndexes[[string]$EntryIndex] = $rowIndex
    }
    $Table.VisibleCount = Get-ApplyProgressVisibleCount -TotalRows @($Table.Rows).Count
    $Table.SummaryLine = ([int]$Table.TopLine + 4 + [int]$Table.VisibleCount)
    $Table.AfterLine = ([int]$Table.TopLine + 5 + [int]$Table.VisibleCount)
    Redraw-ApplyProgressViewport -Table $Table
    return $rowIndex
}

function Resolve-ApplyProgressRowIndex {
    param([object]$Table, [int]$Index, [switch]$ShowIfHidden)
    if ($null -eq $Table -or $Index -lt 0) { return -1 }
    if ($null -ne $Table.PSObject.Properties["EntryRowIndexes"]) {
        if ($null -eq $Table.PSObject.Properties["Entries"] -or $Index -ge @($Table.Entries).Count) { return -1 }
        $key = [string]$Index
        if (-not $Table.EntryRowIndexes.ContainsKey($key)) { return -1 }
        $mappedIndex = [int]$Table.EntryRowIndexes[$key]
        if ($mappedIndex -lt 0 -and $ShowIfHidden) {
            $mappedIndex = Add-ApplyProgressVisibleRow -Table $Table -EntryIndex $Index
        }
        return $mappedIndex
    }
    if ($Index -ge @($Table.Rows).Count) { return -1 }
    return $Index
}

function Update-ApplyProgressRow {
    param(
        [object]$Table,
        [int]$Index,
        [string]$Status,
        [Nullable[Int64]]$CopiedBytes = $null,
        [Nullable[Int64]]$TotalBytes = $null,
        [Nullable[DateTime]]$StartedAt = $null,
        [switch]$Complete,
        [switch]$ForceRender,
        [switch]$ShowIfHidden
    )
    $rowIndex = Resolve-ApplyProgressRowIndex -Table $Table -Index $Index -ShowIfHidden:$ShowIfHidden
    if ($rowIndex -lt 0 -or $rowIndex -ge @($Table.Rows).Count) { return }
    $row = $Table.Rows[$rowIndex]
    if (-not [string]::IsNullOrWhiteSpace($Status)) { $row.Status = $Status }
    if ($CopiedBytes -ne $null) { $row.CopiedBytes = [int64]$CopiedBytes }
    if ($TotalBytes -ne $null) {
        $row.TotalBytes = [int64]$TotalBytes
        if ([bool]$row.IsFileEntry) { $row.ShowsSize = $true }
    }
    if ($StartedAt -ne $null) { $row.StartedAt = [datetime]$StartedAt }
    if ($Complete) { $row.IsComplete = $true }
    $Table.CurrentIndex = $rowIndex

    $now = Get-Date
    if (-not $ForceRender -and (($now - $row.LastRender).TotalMilliseconds -lt 150)) { return }
    $row.LastRender = $now
    $line = Format-ApplyProgressRow -Table $Table -Row $row
    $color = Get-ApplyStatusColor $row
    $newVisibleStart = Get-ApplyProgressVisibleStart -Table $Table -CurrentIndex $rowIndex
    if ($newVisibleStart -ne [int]$Table.VisibleStart) {
        $Table.VisibleStart = $newVisibleStart
        Redraw-ApplyProgressViewport -Table $Table
        return
    }

    if (-not $Table.Interactive) {
        return
    }

    try {
        $visibleIndex = $rowIndex - [int]$Table.VisibleStart
        if ($visibleIndex -lt 0 -or $visibleIndex -ge [int]$Table.VisibleCount) { return }
        [Console]::SetCursorPosition(0, $Table.TopLine + 3 + $visibleIndex)
        Write-Host -NoNewline (" " * $Table.Layout.LineWidth)
        [Console]::SetCursorPosition(0, $Table.TopLine + 3 + $visibleIndex)
        Write-Host -NoNewline ($line.PadRight($Table.Layout.LineWidth)) -ForegroundColor $color
        [Console]::SetCursorPosition(0, $Table.SummaryLine)
        $summary = Get-ApplyProgressSummary $Table
        Write-Host -NoNewline (" " * $Table.Layout.LineWidth)
        [Console]::SetCursorPosition(0, $Table.SummaryLine)
        Write-Host -NoNewline ($summary.PadRight($Table.Layout.LineWidth)) -ForegroundColor DarkGray
        [Console]::SetCursorPosition(0, $Table.AfterLine)
    } catch {
        $Table.Interactive = $false
    }
}

function Wait-Back {
    param([string]$Prompt = "Press any key to continue...")
    if ($script:SuppressPause) { return }
    Write-Host ""
    Write-Color $Prompt "DarkGray" -NoNewLine
    [void][Console]::ReadKey($true)
}

function Read-KeyChoice {
    param([string]$Prompt = "Select: ")
    Write-Color $Prompt "Cyan" -NoNewLine
    $key = [Console]::ReadKey($true)
    if ($key.Key -eq [ConsoleKey]::Escape) {
        Write-Host "Esc"
        return $null
    }
    Write-Host $key.KeyChar
    return [string]$key.KeyChar
}

function Read-LineOrEsc {
    param([string]$Prompt)
    Write-Color $Prompt "Cyan" -NoNewLine
    $buffer = New-Object System.Text.StringBuilder
    while ($true) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq [ConsoleKey]::Escape) { Write-Host ""; return $null }
        if ($key.Key -eq [ConsoleKey]::Enter) { Write-Host ""; return $buffer.ToString() }
        if ($key.Key -eq [ConsoleKey]::Backspace) {
            if ($buffer.Length -gt 0) {
                [void]$buffer.Remove($buffer.Length - 1, 1)
                Write-Host -NoNewline "`b `b"
            }
            continue
        }
        if ($key.KeyChar -ne [char]0) {
            [void]$buffer.Append($key.KeyChar)
            Write-Host -NoNewline $key.KeyChar
        }
    }
}

function Read-NumberOrEsc {
    param([string]$Prompt = "Select: ")
    while ($true) {
        $value = Read-LineOrEsc $Prompt
        if ($null -eq $value) { return $null }
        $value = $value.Trim()
        if ($value -match '^\d+$') { return [int]$value }
        Write-Color "Invalid input. Type a number or press Esc." "Yellow"
    }
}

function Read-EnterOrEsc {
    param([string]$Prompt)
    Write-Color $Prompt "Yellow"
    Write-Color "Enter = continue   Esc = back" "DarkGray"
    while ($true) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq [ConsoleKey]::Enter) { return $true }
        if ($key.Key -eq [ConsoleKey]::Escape) { return $false }
    }
}

function Normalize-PathText {
    param([string]$Path)
    if ($null -eq $Path) { return "" }
    $p = $Path.Trim().Trim('"').Replace('/', '\')
    while ($p.EndsWith('\') -and $p.Length -gt 3) { $p = $p.Substring(0, $p.Length - 1) }
    return $p
}

function Format-ErrorSummary {
    param([string]$Message)
    if ([string]::IsNullOrWhiteSpace($Message)) { return "" }
    if ($Message -like '*network name*' -or $Message -like '*not found*network*') { return "NETWORK_ERROR" }
    if ($Message -like '*access*denied*' -or $Message -like '*permission*denied*') { return "ACCESS_DENIED" }
    if ($Message -like '*disk*full*' -or $Message -like '*storage*') { return "DISK_FULL" }
    if ($Message -like '*file exists*') { return "FILE_EXISTS" }
    if ($Message -like '*file not found*' -or $Message -like '*cannot find*') { return "FILE_NOT_FOUND" }
    if ($Message -like '*path*not found*' -or $Message -like '*not exist*') { return "PATH_NOT_FOUND" }
    if ($Message -like '*in use*' -or $Message -like '*locked*' -or $Message -like '*used by*') { return "FILE_IN_USE" }
    if ($Message -like '*timeout*' -or $Message -like '*timed out*') { return "TIMEOUT" }
    if ($Message -like '*unauthorized*' -or $Message -like '*credentials*') { return "UNAUTHORIZED" }
    return "ERROR"
}

function Get-AutoPairName {
    param([string]$Source, [string]$Dest)
    foreach ($candidate in @($Source, $Dest)) {
        $path = Normalize-PathText $candidate
        if ([string]::IsNullOrWhiteSpace($path)) { continue }
        if ($path -match '^([A-Za-z]):\\?$') { return ($Matches[1].ToUpperInvariant() + " Drive") }
        try {
            $leaf = Split-Path -Leaf $path
            if (-not [string]::IsNullOrWhiteSpace($leaf)) {
                return ([regex]::Replace($leaf.Trim(), '\s+', ' '))
            }
        } catch {}
        $segments = @($path -split '\\' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($segments.Count -gt 0) {
            return ([regex]::Replace($segments[$segments.Count - 1].Trim(), '\s+', ' '))
        }
    }
    return "Backup Pair"
}

function Resolve-DestinationPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
    $maps = $script:Config.DriveMaps
    if ($maps -ne $null) {
        foreach ($p in $maps.PSObject.Properties) {
            $drive = $p.Name.TrimEnd('\')
            $target = [string]$p.Value
            if ([string]::IsNullOrWhiteSpace($drive) -or [string]::IsNullOrWhiteSpace($target)) { continue }
            if ($Path.Equals($drive, [System.StringComparison]::OrdinalIgnoreCase)) { return $target.TrimEnd('\') }
            $prefix = $drive + "\"
            if ($Path.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                try { return (Join-Path $target.TrimEnd('\') $Path.Substring($prefix.Length) -ErrorAction Stop) } catch { return [System.IO.Path]::Combine($target.TrimEnd('\'), $Path.Substring($prefix.Length)) }
            }
        }
    }
    return $Path
}

function Get-RelativePath {
    param([string]$Root, [string]$Path)
    if (-not (Test-PathInsideRoot $Root $Path)) { return "" }
    return [IO.Path]::GetFullPath($Path).Substring([IO.Path]::GetFullPath($Root).TrimEnd('\').Length + 1)
}

function Join-PathSafe {
    param([string]$Base, [string]$Rel)
    if ([string]::IsNullOrWhiteSpace($Rel) -or $Rel -eq '.') { return $Base }
    $relative = Normalize-QueueRelPath $Rel
    $joined = [IO.Path]::GetFullPath([IO.Path]::Combine($Base, $relative))
    if (-not (Test-PathInsideRoot $Base $joined)) { throw "Path escapes its configured root" }
    return $joined
}

function Assert-NoReparsePath {
    param([string]$Path)
    $current = [IO.Path]::GetFullPath($Path)
    while (-not [string]::IsNullOrWhiteSpace($current)) {
        $probe = Get-ExactPathProbe $current
        if ($probe.State -eq 'Error') { throw "Cannot inspect path: $current ($($probe.ErrorMessage))" }
        if ($probe.State -eq 'Exists' -and ($probe.Item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "Reparse points are not supported: $current"
        }
        $parent = [IO.Path]::GetDirectoryName($current.TrimEnd('\'))
        if ($parent -eq $current) { break }
        $current = $parent
    }
}

function Assert-PairLayout {
    param([object]$Pair)
    $source = Expand-TextPath ([string]$Pair.Source)
    $destination = Resolve-DestinationPath ([string]$Pair.Dest)
    foreach ($path in @($source,$destination)) {
        if ($path -notmatch '^(?:[A-Za-z]:\\|\\\\[^\\]+\\[^\\]+(?:\\|$))' -or $path -match '^\\\\[?.]\\') { throw 'Pairs require absolute drive or UNC paths' }
        Assert-NoReparsePath $path
    }
    $source = [IO.Path]::GetFullPath($source).TrimEnd('\')
    $destination = [IO.Path]::GetFullPath($destination).TrimEnd('\')
    if ($source -ieq $destination -or (Test-PathInsideRoot $source $destination) -or (Test-PathInsideRoot $destination $source)) { throw 'Source and destination must not overlap' }
    foreach ($other in @(Get-Pairs)) {
        $otherSource = [IO.Path]::GetFullPath((Expand-TextPath ([string]$other.Source))).TrimEnd('\')
        if ($destination -ieq $otherSource -or (Test-PathInsideRoot $otherSource $destination) -or (Test-PathInsideRoot $destination $otherSource)) { throw 'Destination overlaps a configured source' }
    }
}

function Get-SafeEntryPaths {
    param([object]$Pair, [object]$Entry)
    Assert-PairLayout $Pair
    $rel = Normalize-QueueRelPath ([string]$Entry.RelPath)
    $source = Join-PathSafe (Expand-TextPath ([string]$Pair.Source)) $rel
    $destination = Join-PathSafe (Resolve-DestinationPath ([string]$Pair.Dest)) $rel
    foreach ($saved in @(@('Source',$source),@('Dest',$destination))) {
        $value = [string]$Entry.($saved[0])
        if ($value -and [IO.Path]::GetFullPath($value) -ine $saved[1]) { throw 'Pair paths changed since this item was queued; review pending work' }
    }
    Assert-NoReparsePath $source
    Assert-NoReparsePath $destination
    return [pscustomobject]@{ Source=$source; Destination=$destination }
}

function Get-SafeTreeItems {
    param([string]$Root, [object]$Pair = $null, [string]$EquivalentRoot = '')
    Assert-NoReparsePath $Root
    $stack = [Collections.Generic.Stack[string]]::new()
    $stack.Push($Root)
    while ($stack.Count -gt 0) {
        $directory = $stack.Pop()
        foreach ($item in @(Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop)) {
            $equivalent = if ($EquivalentRoot) { Join-PathSafe $EquivalentRoot (Get-RelativePath $Root $item.FullName) } else { $item.FullName }
            if ($null -ne $Pair -and (Test-Excluded $Pair $equivalent $item.PSIsContainer)) { continue }
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse point encountered: $($item.FullName)" }
            $item
            if ($item.PSIsContainer) { $stack.Push($item.FullName) }
        }
    }
}

function Remove-OwnedPath {
    param([string]$Root, [string]$Path, [switch]$Recurse)
    if (-not (Test-PathInsideRoot $Root $Path)) { throw 'Refusing removal outside the specified root' }
    Assert-NoReparsePath $Path
    $probe = Get-ExactPathProbe $Path
    if ($probe.State -eq 'Missing') { return }
    if ($probe.State -ne 'Exists') { throw 'Removal target is unreadable' }
    if ($probe.IsDirectory) {
        if ($Recurse) {
            $items = @(Get-SafeTreeItems $Path)
            foreach ($file in @($items | Where-Object { -not $_.PSIsContainer })) {
                [IO.File]::SetAttributes($file.FullName, ($file.Attributes -band (-bnot [IO.FileAttributes]::ReadOnly)))
                [IO.File]::Delete($file.FullName)
            }
            foreach ($dir in @($items | Where-Object PSIsContainer | Sort-Object { $_.FullName.Length } -Descending)) { [IO.Directory]::Delete($dir.FullName) }
        }
        [IO.Directory]::Delete($Path)
    } else {
        [IO.File]::SetAttributes($Path, ($probe.Item.Attributes -band (-bnot [IO.FileAttributes]::ReadOnly)))
        [IO.File]::Delete($Path)
    }
    if ((Get-ExactPathProbe $Path).State -ne 'Missing') { throw 'Removal could not be verified' }
}

function Remove-VerifiedDestination {
    param([object]$Pair, [string]$RelPath)
    $source = Join-PathSafe $Pair.Source $RelPath
    $root = Resolve-DestinationPath $Pair.Dest
    $destination = Join-PathSafe $root $RelPath
    Assert-PairLayout $Pair
    Assert-NoReparsePath $source
    Assert-NoReparsePath $destination
    $probe = Get-ExactPathProbe $destination
    if ($probe.State -eq 'Error') { throw 'Destination check failed' }
    if ($probe.State -eq 'Exists' -and $probe.IsDirectory) {
        # Never remove excluded descendants by deleting their parent.
        foreach ($item in @(Get-SafeTreeItems $destination)) {
            $equivalent = Join-PathSafe $source (Get-RelativePath $destination $item.FullName)
            if (Test-Excluded $Pair $equivalent $item.PSIsContainer) { throw 'Directory contains excluded content; delete retained' }
        }
    }
    $sourceRoot = Get-ExactPathProbe $Pair.Source
    $destRoot = Get-ExactPathProbe ([IO.Path]::GetPathRoot($root))
    if ($sourceRoot.State -ne 'Exists' -or -not $sourceRoot.IsDirectory -or $destRoot.State -ne 'Exists' -or -not $destRoot.IsDirectory) { throw 'Source or destination root unavailable' }
    if ((Get-ExactPathProbe $source).State -ne 'Missing') { throw 'Source restored or indeterminate; delete retained' }
    if ($probe.State -eq 'Exists') { Remove-OwnedPath $root $destination -Recurse }
}

function Test-NameMatchesAny {
    param([string]$Text, [object[]]$Patterns)
    foreach ($pat in $Patterns) {
        if ([string]::IsNullOrWhiteSpace([string]$pat)) { continue }
        if ($Text -like [string]$pat) { return $true }
    }
    return $false
}

function Test-RelativeDirExcluded {
    param([string]$RelPath, [string]$Pattern)
    $p = ([string]$Pattern) -replace '/', '\'
    $p = $p.Trim('\')
    if ([string]::IsNullOrWhiteSpace($p)) { return $false }
    if ($p -notmatch '\\') { return $false }
    return ($RelPath -like $p -or $RelPath -like ($p + "\*"))
}

function Convert-PairExcludeDirForRobocopy {
    param([object]$Pair, [string]$Pattern)
    $p = ([string]$Pattern) -replace '/', '\'
    if ([string]::IsNullOrWhiteSpace($p)) { return $null }
    if ($p -notmatch '\\' -or [System.IO.Path]::IsPathRooted($p)) { return $p }
    return Join-PathSafe $Pair.Source $p.TrimStart('\')
}

function Test-Excluded {
    param([object]$Pair, [string]$FullPath, [Nullable[bool]]$IsDirectory = $null)
    $rel = Get-RelativePath $Pair.Source $FullPath
    if ([string]::IsNullOrWhiteSpace($rel)) { return $false }
    if ($rel -match '(?i)(?:^|\\)\..+\.(?:mqtmp|mqbackup|mqdirtemp|mbtmp|mbbackup)-[0-9a-f]{32}(?:\\|$)') { return $true }
    $relNorm = $rel -replace '/', '\'
    $segments = @($relNorm -split '\\' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $isDirectoryKnown = ($IsDirectory -ne $null)
    if (-not $isDirectoryKnown) {
        try {
            if (Test-Path -LiteralPath $FullPath) {
                $IsDirectory = [bool](Test-Path -LiteralPath $FullPath -PathType Container)
                $isDirectoryKnown = $true
            }
        } catch {}
    }
    $dirPatterns = @()
    $dirPatterns += @(Get-Array $script:Config.GlobalExcludeDirs)
    $pairDirPatterns = @(Get-MapArray "PairExcludeDirs" $Pair.Name)
    $dirPatterns += $pairDirPatterns
    $dirSegments = $segments
    if ($isDirectoryKnown -and -not [bool]$IsDirectory -and $segments.Count -gt 0) {
        $dirSegments = if ($segments.Count -gt 1) { @($segments[0..($segments.Count - 2)]) } else { @() }
    }
    foreach ($seg in $dirSegments) {
        if (Test-NameMatchesAny $seg $dirPatterns) { return $true }
    }
    $directoryRel = $relNorm
    if ($isDirectoryKnown -and -not [bool]$IsDirectory) {
        $directoryRel = Split-Path -Path $relNorm -Parent
    }
    foreach ($pat in $pairDirPatterns) {
        if (Test-RelativeDirExcluded $directoryRel ([string]$pat)) { return $true }
    }
    if ($isDirectoryKnown -and [bool]$IsDirectory) { return $false }
    $filePatterns = @()
    $filePatterns += @(Get-Array $script:Config.GlobalExcludeFiles)
    $filePatterns += @(Get-MapArray "PairExcludeFiles" $Pair.Name)
    $leaf = Split-Path -Path $relNorm -Leaf
    foreach ($pat in $filePatterns) {
        $p = ([string]$pat) -replace '/', '\'
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        if ($leaf -like $p -or $relNorm -like $p -or $relNorm -like ("*" + $p)) { return $true }
    }
    return $false
}

function Test-DestRootAvailable {
    param([string]$DestPath)
    $resolved = Resolve-DestinationPath $DestPath
    try {
        $root = [System.IO.Path]::GetPathRoot($resolved)
        if ([string]::IsNullOrWhiteSpace($root)) { return $false }
        return (Test-Path -LiteralPath $root)
    } catch {
        return $false
    }
}

function Initialize-PhysicalPathApi {
    if ("MiraQueue.NativePath" -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace MiraQueue {
    public static class NativePath {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern SafeFileHandle CreateFile(
            string fileName, uint desiredAccess, uint shareMode, IntPtr securityAttributes,
            uint creationDisposition, uint flagsAndAttributes, IntPtr templateFile);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern uint GetFinalPathNameByHandle(
            SafeFileHandle file, StringBuilder path, uint pathLength, uint flags);

        public static string GetFinalPath(string path) {
            using (SafeFileHandle handle = CreateFile(path, 0, 7, IntPtr.Zero, 3, 0x02000000, IntPtr.Zero)) {
                if (handle.IsInvalid) throw new Win32Exception(Marshal.GetLastWin32Error());
                StringBuilder buffer = new StringBuilder(32768);
                uint length = GetFinalPathNameByHandle(handle, buffer, (uint)buffer.Capacity, 0);
                if (length == 0) throw new Win32Exception(Marshal.GetLastWin32Error());
                if (length >= buffer.Capacity) throw new InvalidOperationException("Resolved path is too long.");
                string value = buffer.ToString();
                if (value.StartsWith(@"\\?\UNC\", StringComparison.OrdinalIgnoreCase)) return @"\\" + value.Substring(8);
                if (value.StartsWith(@"\\?\", StringComparison.OrdinalIgnoreCase)) return value.Substring(4);
                return value;
            }
        }
    }
}
'@
}

function Get-PhysicalDestinationKey {
    param([string]$Destination)
    try {
        $full = [System.IO.Path]::GetFullPath($Destination)
        $candidate = Split-Path -Parent $full
        $remaining = New-Object System.Collections.Generic.List[string]
        $remaining.Insert(0, (Split-Path -Leaf $full))
        while (-not [System.IO.Directory]::Exists($candidate)) {
            $leaf = Split-Path -Leaf $candidate
            $parent = Split-Path -Parent $candidate
            if ([string]::IsNullOrWhiteSpace($leaf) -or [string]::IsNullOrWhiteSpace($parent) -or $parent -eq $candidate) {
                throw "No existing destination ancestor"
            }
            $remaining.Insert(0, $leaf)
            $candidate = $parent
        }
        Initialize-PhysicalPathApi
        $resolved = [MiraQueue.NativePath]::GetFinalPath($candidate)
        foreach ($segment in $remaining) { $resolved = [System.IO.Path]::Combine($resolved, $segment) }
        return [System.IO.Path]::GetFullPath($resolved).TrimEnd('\').ToUpperInvariant()
    } catch {
        Write-Log "WARN" ("Could not resolve physical destination path; using conservative serialization: " + $Destination)
        return "__UNRESOLVED_PHYSICAL_DESTINATION__"
    }
}

function Test-TcpPortQuick {
    param(
        [string]$Server,
        [int]$Port = 445,
        [int]$TimeoutMs = 350
    )
    if ([string]::IsNullOrWhiteSpace($Server)) { return $false }
    $client = $null
    try {
        $client = [System.Net.Sockets.TcpClient]::new()
        $async = $client.BeginConnect($Server, $Port, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) {
            return $false
        }
        $client.EndConnect($async)
        return [bool]$client.Connected
    } catch {
        return $false
    } finally {
        if ($null -ne $client) { $client.Close() }
    }
}

function Test-DestRootAvailableFast {
    param([string]$DestPath)
    $resolved = Resolve-DestinationPath $DestPath
    try {
        $root = [System.IO.Path]::GetPathRoot($resolved)
        if ([string]::IsNullOrWhiteSpace($root)) { return $false }
        $cacheKey = $root.ToLowerInvariant()
        $now = Get-Date
        if ($script:DriveStatusCache.ContainsKey($cacheKey)) {
            $cached = $script:DriveStatusCache[$cacheKey]
            if ($null -ne $cached -and $cached.Expires -gt $now) {
                return [bool]$cached.Online
            }
        }

        $online = $false
        if ($root -match '^\\\\([^\\]+)\\') {
            $online = Test-TcpPortQuick -Server $Matches[1] -Port 445 -TimeoutMs 350
        } else {
            $online = Test-Path -LiteralPath $root -PathType Container -ErrorAction SilentlyContinue
        }

        $script:DriveStatusCache[$cacheKey] = [pscustomobject]@{
            Online = [bool]$online
            Expires = $now.AddSeconds(2)
        }
        return [bool]$online
    } catch {
        return $false
    }
}



function Enter-ApplyLock {
    param([string]$Operation = 'Mirror operation', [switch]$Quiet)
    if ($null -ne $script:ApplyLockStream) { return $false }
    if ([string]::IsNullOrWhiteSpace($script:ApplyLockPath)) { throw 'Apply lock path is not initialized' }
    try {
        # Holding the handle avoids PID reuse, stale-age stealing and release/reacquire races.
        $script:ApplyLockStream = [IO.File]::Open($script:ApplyLockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        $script:ApplyLockStream.SetLength(0)
        $bytes = [Text.Encoding]::UTF8.GetBytes([string]$PID)
        $script:ApplyLockStream.Write($bytes,0,$bytes.Length)
        $script:ApplyLockStream.Flush()
        return $true
    } catch {
        if ($null -ne $script:ApplyLockStream) { $script:ApplyLockStream.Dispose(); $script:ApplyLockStream=$null }
        Write-Log 'LOCK' ("${Operation} blocked: " + $_.Exception.Message)
        if (-not $Quiet) { Write-Color "${Operation} blocked: another operation owns the lock or it is inaccessible." 'Yellow'; Wait-Back }
        return $false
    }
}

function Exit-ApplyLock {
    if ($null -ne $script:ApplyLockStream) { $script:ApplyLockStream.Dispose(); $script:ApplyLockStream=$null }
    # The reusable lock file is removed only by uninstall. An unlocked file is harmless.
}

function Find-PairByName {
    param([string]$Name)
    foreach ($pair in Get-Pairs) {
        if ([string]$pair.Name -ieq [string]$Name) { return $pair }
    }
    return $null
}

function New-QueueEntry {
    param(
        [object]$Pair,
        [string]$FullPath,
        [string]$Action,
        [Nullable[bool]]$KnownIsDirectory = $null,
        [ValidateSet("Created","Changed","Deleted","RenamedOld","RenamedNew","Snapshot","Legacy")]
        [string]$EventKind = "Legacy",
        [ValidateSet("Absent","Present","Unknown")]
        [string]$BaselineState = "Unknown"
    )
    $rel = Get-RelativePath $Pair.Source $FullPath
    if ([string]::IsNullOrWhiteSpace($rel)) { return $null }
    $exists = Test-Path -LiteralPath $FullPath
    $isDir = $false
    if ($KnownIsDirectory -ne $null) { $isDir = [bool]$KnownIsDirectory }
    elseif ($exists) { $isDir = Test-Path -LiteralPath $FullPath -PathType Container }
    $size = $null
    $lastWrite = $null
    if ($exists -and -not $isDir) {
        try {
            $fi = Get-Item -LiteralPath $FullPath -Force -ErrorAction Stop
            $size = [int64]$fi.Length
            $lastWrite = $fi.LastWriteTimeUtc.ToString("o")
        } catch {}
    }
    $operation = if ($Action -eq "Delete") { "Delete" } elseif ($BaselineState -eq "Absent") { "Add" } else { "Update" }
    [pscustomobject][ordered]@{
        SchemaVersion = 2
        Id = [guid]::NewGuid().ToString()
        TimeUtc = (Get-Date).ToUniversalTime().ToString("o")
        PairName = [string]$Pair.Name
        Action = [string]$Action
        Operation = $operation
        EventKind = $EventKind
        BaselineState = $BaselineState
        RelPath = [string]$rel
        Source = [string]$FullPath
        Dest = [string](Join-PathSafe (Resolve-DestinationPath $Pair.Dest) $rel)
        IsDirectory = [bool]$isDir
        Size = $size
        LastWriteTimeUtc = $lastWrite
    }
}

function ConvertTo-UtcTimestamp {
    param([object]$Value)
    if ($Value -is [datetime]) {
        $date=[datetime]$Value
        if ($date.Kind -eq [DateTimeKind]::Unspecified) { $date=[datetime]::SpecifyKind($date,[DateTimeKind]::Utc) }
        return $date.ToUniversalTime().ToString('o')
    }
    if ([string]::IsNullOrWhiteSpace([string]$Value)) { throw 'Missing UTC timestamp' }
    return [datetimeoffset]::Parse([string]$Value,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::AssumeUniversal).UtcDateTime.ToString('o')
}

function ConvertTo-QueueV2Entry {
    param([object]$Entry)
    if ($null -eq $Entry -or [string]::IsNullOrWhiteSpace([string]$Entry.PairName) -or [string]::IsNullOrWhiteSpace([string]$Entry.RelPath)) { throw 'Queue record requires PairName and RelPath' }
    if ([string]$Entry.PairName -match '[|\x00-\x1f]') { throw 'Invalid pair name in queue' }
    if ([string]$Entry.Action -notin @('Upsert','Delete')) { throw 'Unrecognized queue action' }
    if ($null -ne $Entry.PSObject.Properties['SchemaVersion'] -and [string]$Entry.SchemaVersion -notin @('1','2')) { throw 'Unsupported queue schema; original queue preserved' }
    if ($null -ne $Entry.PSObject.Properties['IsDirectory'] -and $Entry.IsDirectory -isnot [bool]) { throw 'Invalid queue directory flag' }
    if ($null -ne $Entry.PSObject.Properties['BaselineState'] -and [string]$Entry.BaselineState -notin @('Absent','Present','Unknown')) { throw 'Invalid queue baseline' }
    $baseline = "Unknown"
    if ($null -ne $Entry.PSObject.Properties["BaselineState"] -and [string]$Entry.BaselineState -in @("Absent","Present","Unknown")) {
        $baseline = [string]$Entry.BaselineState
    }
    $eventKind = if ($null -ne $Entry.PSObject.Properties["EventKind"] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.EventKind)) { [string]$Entry.EventKind } else { "Legacy" }
    $action = if ([string]$Entry.Action -eq "Delete") { "Delete" } else { "Upsert" }
    $operation = if ($action -eq "Delete") { "Delete" } elseif ($baseline -eq "Absent") { "Add" } else { "Update" }
    return [pscustomobject][ordered]@{
        SchemaVersion = 2
        Id = $(if ($null -ne $Entry.PSObject.Properties["Id"] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.Id)) { [string]$Entry.Id } else { [guid]::NewGuid().ToString() })
        TimeUtc = $(if ($null -ne $Entry.PSObject.Properties["TimeUtc"]) { ConvertTo-UtcTimestamp $Entry.TimeUtc } else { (Get-Date).ToUniversalTime().ToString("o") })
        PairName = [string]$Entry.PairName
        Action = $action
        Operation = $operation
        EventKind = $eventKind
        BaselineState = $baseline
        RelPath = Normalize-QueueRelPath ([string]$Entry.RelPath)
        Source = [string]$Entry.Source
        Dest = [string]$Entry.Dest
        IsDirectory = [bool]$Entry.IsDirectory
        Size = $Entry.Size
        LastWriteTimeUtc = $(if ($null -eq $Entry.LastWriteTimeUtc -or [string]::IsNullOrWhiteSpace([string]$Entry.LastWriteTimeUtc)) { $null } else { ConvertTo-UtcTimestamp $Entry.LastWriteTimeUtc })
    }
}

function Add-PendingMetric {
    param([string]$Name, [long]$Started = 0, [long]$Count = 1, [string]$Pair = "", [string]$Operation = "")
    $perf = $script:PendingPerformance
    if ($null -eq $perf) { return }
    $elapsed = if ($Started -gt 0) { ([Diagnostics.Stopwatch]::GetTimestamp() - $Started) * 1000.0 / [Diagnostics.Stopwatch]::Frequency } else { 0.0 }
    $perf.Counts[$Name] = [long]$perf.Counts[$Name] + $Count
    $perf.Milliseconds[$Name] = [double]$perf.Milliseconds[$Name] + $elapsed
    if (-not [string]::IsNullOrWhiteSpace($Pair)) {
        if (-not $perf.ByPair.ContainsKey($Pair)) { $perf.ByPair[$Pair] = @{ Counts=@{}; Milliseconds=@{} } }
        $bucket = $perf.ByPair[$Pair]
        $bucket.Counts[$Name] = [long]$bucket.Counts[$Name] + $Count
        $bucket.Milliseconds[$Name] = [double]$bucket.Milliseconds[$Name] + $elapsed
    }
    if (-not [string]::IsNullOrWhiteSpace($Operation)) {
        if (-not $perf.ByOperation.ContainsKey($Operation)) { $perf.ByOperation[$Operation] = @{ Counts=@{}; Milliseconds=@{} } }
        $bucket = $perf.ByOperation[$Operation]
        $bucket.Counts[$Name] = [long]$bucket.Counts[$Name] + $Count
        $bucket.Milliseconds[$Name] = [double]$bucket.Milliseconds[$Name] + $elapsed
    }
}

function Invoke-PendingPathProbe {
    param([string]$Path, [string]$Kind = "DestinationProbe", [string]$Pair = "", [string]$Operation = "")
    $started = if ($null -ne $script:PendingPerformance) { [Diagnostics.Stopwatch]::GetTimestamp() } else { 0 }
    try { return (Get-ExactPathProbe $Path) }
    finally { if ($null -ne $script:PendingPerformance) { Add-PendingMetric $Kind $started 1 $Pair $Operation } }
}

function Enter-QueueMutex {
    param([int]$TimeoutMs = 10000)
    $mutex = $null
    $started = if ($null -ne $script:PendingPerformance) { [Diagnostics.Stopwatch]::GetTimestamp() } else { 0 }
    try {
        $mutex = New-Object System.Threading.Mutex($false, $script:QueueMutexName)
        try {
            if (-not $mutex.WaitOne($TimeoutMs, $false)) {
                if ($null -ne $script:PendingPerformance) { Add-PendingMetric "MutexTimeout" }
                $mutex.Dispose(); return $null
            }
        } catch [System.Threading.AbandonedMutexException] {}
        if ($null -ne $script:PendingPerformance) {
            $mutex | Add-Member -NotePropertyName PendingHeldSince -NotePropertyValue ([Diagnostics.Stopwatch]::GetTimestamp())
        }
        return $mutex
    } catch {
        if ($null -ne $mutex) { try { $mutex.Dispose() } catch {} }
        return $null
    } finally { if ($null -ne $script:PendingPerformance) { Add-PendingMetric "MutexWait" $started } }
}

function Exit-QueueMutex {
    param([object]$Mutex)
    if ($null -eq $Mutex) { return }
    if ($null -ne $script:PendingPerformance -and $null -ne $Mutex.PSObject.Properties['PendingHeldSince']) {
        Add-PendingMetric "MutexHeld" ([long]$Mutex.PendingHeldSince)
    }
    try { $Mutex.ReleaseMutex() | Out-Null } catch {}
    try { $Mutex.Dispose() } catch {}
}

function Read-QueueEntriesUnlocked {
    $items = [Collections.Generic.List[object]]::new()
    $started = if ($null -ne $script:PendingPerformance) { [Diagnostics.Stopwatch]::GetTimestamp() } else { 0 }
    try { $lines = [IO.File]::ReadAllLines($script:QueuePath, [Text.Encoding]::UTF8) }
    finally { if ($null -ne $script:PendingPerformance) { Add-PendingMetric 'QueueRead' $started } }
    $lineNumber = 0
    foreach ($line in $lines) {
        $lineNumber++
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $record = $line | ConvertFrom-Json -ErrorAction Stop
            $null = ConvertTo-QueueV2Entry $record
            $items.Add($record)
        } catch { throw "Invalid queue record at line ${lineNumber}; queue preserved: $($_.Exception.Message)" }
    }
    return @($items.ToArray())
}

function Read-QueueEntries {
    $mutex = Enter-QueueMutex
    if ($null -eq $mutex) { throw 'Queue read timed out waiting for lock' }
    try { return @(Read-QueueEntriesUnlocked) } finally { Exit-QueueMutex $mutex }
}

function Get-QueuePathNode {
    param([hashtable]$PathIndex, [object]$Entry, [switch]$Create)
    $pairKey = ([string]$Entry.PairName).ToUpperInvariant()
    if (-not $PathIndex.ContainsKey($pairKey)) {
        if (-not $Create) { return $null }
        $PathIndex[$pairKey] = @{ Children=@{}; Key=$null }
    }
    $node = $PathIndex[$pairKey]
    foreach ($segment in ((Normalize-QueueRelPath ([string]$Entry.RelPath)).ToUpperInvariant().Split('\'))) {
        if (-not $node.Children.ContainsKey($segment)) {
            if (-not $Create) { return $null }
            $node.Children[$segment] = @{ Children=@{}; Key=$null }
        }
        $node = $node.Children[$segment]
    }
    return $node
}

function Remove-QueueDescendants {
    param([hashtable]$Dictionary, [object]$Parent, [switch]$OnlyNew, [hashtable]$PathIndex = $null)
    if ($null -ne $PathIndex) {
        $parentNode = Get-QueuePathNode $PathIndex $Parent
        if ($null -eq $parentNode) { return }
        $pendingNodes = [System.Collections.Generic.Stack[object]]::new()
        foreach ($child in $parentNode.Children.Values) { $pendingNodes.Push($child) }
        while ($pendingNodes.Count -gt 0) {
            $node = $pendingNodes.Pop()
            foreach ($child in $node.Children.Values) { $pendingNodes.Push($child) }
            if ($null -ne $node.Key -and $Dictionary.ContainsKey($node.Key)) {
                if (-not $OnlyNew -or [string]$Dictionary[$node.Key].BaselineState -eq "Absent") {
                    $Dictionary.Remove($node.Key)
                    $node.Key = $null
                }
            }
        }
        if (-not $OnlyNew) { $parentNode.Children.Clear() }
        return
    }
    # Small standalone merges (e.g. the debounce slot) do not need an index.
    $prefix = (Normalize-QueueRelPath ([string]$Parent.RelPath)) + "\"
    foreach ($key in @($Dictionary.Keys)) {
        $candidate = $Dictionary[$key]
        if ([string]$candidate.PairName -ine [string]$Parent.PairName) { continue }
        $rel = Normalize-QueueRelPath ([string]$candidate.RelPath)
        if (-not $rel.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        if ($OnlyNew -and [string]$candidate.BaselineState -ne "Absent") { continue }
        $Dictionary.Remove($key)
    }
}

function Merge-QueueEntryState {
    param([hashtable]$Dictionary, [object]$Incoming, [hashtable]$PathIndex = $null)
    $entry = ConvertTo-QueueV2Entry $Incoming
    if ($null -eq $entry) { return }
    $key = Get-QueueEntryKey $entry
    $existing = if ($Dictionary.ContainsKey($key)) { $Dictionary[$key] } else { $null }

    if ($entry.Action -eq "Delete") {
        Remove-QueueDescendants -Dictionary $Dictionary -Parent $entry -PathIndex $PathIndex
        if ($null -ne $existing -and $existing.Action -eq "Upsert" -and [string]$existing.BaselineState -eq "Absent") {
            $Dictionary.Remove($key)
            return
        }
        if ([string]$entry.BaselineState -eq "Absent") {
            return
        }
        if ($null -ne $existing -and [string]$existing.BaselineState -ne "Unknown") {
            $entry.BaselineState = [string]$existing.BaselineState
        }
        $entry.Operation = "Delete"
        $Dictionary[$key] = $entry
        if ($null -ne $PathIndex) { (Get-QueuePathNode $PathIndex $entry -Create).Key = $key }
        return
    }

    if ($null -ne $existing) {
        if ([string]$existing.BaselineState -eq "Absent") {
            $entry.BaselineState = "Absent"
        } elseif ($existing.Action -eq "Delete") {
            $entry.BaselineState = $(if ([string]$existing.BaselineState -eq "Absent") { "Absent" } elseif ([string]$existing.BaselineState -eq "Unknown") { "Unknown" } else { "Present" })
        } elseif ([string]$entry.BaselineState -eq "Unknown") {
            $entry.BaselineState = [string]$existing.BaselineState
        }
    }
    $entry.Operation = $(if ([string]$entry.BaselineState -eq "Absent") { "Add" } else { "Update" })
    $Dictionary[$key] = $entry
    if ($null -ne $PathIndex) { (Get-QueuePathNode $PathIndex $entry -Create).Key = $key }
}

function Get-QueueDictionary {
    param([object[]]$Entries, [hashtable]$PathIndex = $null)
    $started = if ($null -ne $script:PendingPerformance) { [Diagnostics.Stopwatch]::GetTimestamp() } else { 0 }
    if ($null -eq $PathIndex) { $PathIndex = @{} }
    $dict = @{}
    try {
        foreach ($entry in $Entries) { Merge-QueueEntryState -Dictionary $dict -Incoming $entry -PathIndex $PathIndex }
        return $dict
    } finally { if ($null -ne $script:PendingPerformance) { Add-PendingMetric "QueueMerge" $started $Entries.Count } }
}

function Get-LatestQueueEntries {
    param([object[]]$Entries)
    $dict = Get-QueueDictionary $Entries
    $started = if ($null -ne $script:PendingPerformance) { [Diagnostics.Stopwatch]::GetTimestamp() } else { 0 }
    try { return @($dict.Values | Sort-Object PairName, RelPath) }
    finally { if ($null -ne $script:PendingPerformance) { Add-PendingMetric "QueueSort" $started $dict.Count } }
}

function Remove-OrphanedUpserts {
    param([object[]]$Entries)
    $started = if ($null -ne $script:PendingPerformance) { [Diagnostics.Stopwatch]::GetTimestamp() } else { 0 }
    try {
        $deleteKeys = @{}
        foreach ($entry in $Entries) {
            if ($entry.Action -eq "Delete") { $deleteKeys[(Get-QueueEntryKey $entry)] = $true }
        }
        if ($deleteKeys.Count -eq 0) { return $Entries }
        foreach ($entry in $Entries) {
            if ($entry.Action -ne "Upsert") { $entry; continue }
            $rel = Normalize-QueueRelPath ([string]$entry.RelPath)
            $covered = $false
            while ($rel.Length -gt 0) {
                if ($deleteKeys.ContainsKey(($entry.PairName + "|" + $rel).ToUpperInvariant())) { $covered = $true; break }
                $separator = $rel.LastIndexOf('\')
                if ($separator -lt 0) { break }
                $rel = $rel.Substring(0, $separator)
            }
            if (-not $covered) { $entry }
        }
    } finally { if ($null -ne $script:PendingPerformance) { Add-PendingMetric "QueueFilter" $started $Entries.Count } }
}

function Write-QueueMetaUnlocked {
    param([object[]]$Entries)
    $queueItem = Get-Item -LiteralPath $script:QueuePath -Force -ErrorAction SilentlyContinue
    $meta = [pscustomobject][ordered]@{
        SchemaVersion = 2
        EffectiveCount = @($Entries).Count
        AddCount = @($Entries | Where-Object { $_.Operation -eq "Add" }).Count
        UpdateCount = @($Entries | Where-Object { $_.Operation -eq "Update" }).Count
        DeleteCount = @($Entries | Where-Object { $_.Operation -eq "Delete" }).Count
        UpdatedUtc = (Get-Date).ToUniversalTime().ToString("o")
        QueueLength = $(if ($queueItem) { [int64]$queueItem.Length } else { 0 })
        QueueWriteTicks = $(if ($queueItem) { [int64]$queueItem.LastWriteTimeUtc.Ticks } else { 0 })
    }
    $tmp = "$script:QueueMetaPath.$PID.$([guid]::NewGuid().ToString('N')).tmp"
    $replaceBackup = "$script:QueueMetaPath.$PID.replace.bak"
    try {
        [System.IO.File]::WriteAllText($tmp, ($meta | ConvertTo-Json -Depth 5), (New-Object System.Text.UTF8Encoding($false)))
        if (Test-Path -LiteralPath $script:QueueMetaPath) { [System.IO.File]::Replace($tmp, $script:QueueMetaPath, $replaceBackup) }
        else { Move-Item -LiteralPath $tmp -Destination $script:QueueMetaPath -Force -ErrorAction Stop }
    } finally {
        if (Test-Path -LiteralPath $tmp) { Remove-OwnedPath ([IO.Path]::GetDirectoryName($tmp)) $tmp }
        if (Test-Path -LiteralPath $replaceBackup) { Remove-OwnedPath $script:DataDir $replaceBackup }
    }
}

function Get-QueueFileFingerprint {
    try {
        $item = Get-Item -LiteralPath $script:QueuePath -Force -ErrorAction Stop
        return ("{0}|{1}" -f [int64]$item.Length, [int64]$item.LastWriteTimeUtc.Ticks)
    } catch {
        return "MISSING"
    }
}







function Get-PendingPairIndex {
    $index = @{}
    foreach ($pair in @(Get-Pairs)) {
        $key = ([string]$pair.Name).ToUpperInvariant()
        if ($index.ContainsKey($key)) { continue } # Preserve Find-PairByName's first-match rule.
        $destination = Resolve-DestinationPath ([string]$pair.Dest)
        $index[$key] = [pscustomobject]@{
            Pair=$pair; Source=[string]$pair.Source; Destination=$destination
            Root=[string][System.IO.Path]::GetPathRoot($destination)
        }
    }
    return $index
}

function Get-PendingDirectoryNames {
    param([string]$Directory, [int]$Limit, [System.Collections.Generic.HashSet[string]]$Wanted)
    # Names only, including hidden/system entries. No recursion and no per-child stat.
    $found = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $enumerator = $null
    $count = 0
    $complete = $false
    $errorText = ""
    $started = if ($null -ne $script:PendingPerformance) { [Diagnostics.Stopwatch]::GetTimestamp() } else { 0 }
    try {
        $enumerator = [System.IO.Directory]::EnumerateFileSystemEntries($Directory).GetEnumerator()
        while ($count -lt $Limit) {
            if (-not $enumerator.MoveNext()) { $complete = $true; break }
            $count++
            $name = [System.IO.Path]::GetFileName([string]$enumerator.Current)
            if ($Wanted.Contains($name)) { [void]$found.Add($name) }
            if ($found.Count -eq $Wanted.Count) { break }
        }
    } catch { $errorText = Format-ErrorSummary $_.Exception.Message }
    finally {
        if ($null -ne $enumerator) { $enumerator.Dispose() }
        if ($null -ne $script:PendingPerformance) {
            Add-PendingMetric "DirectoryEnumeration" $started
            Add-PendingMetric "EnumeratedNames" 0 $count
            if ($errorText) { Add-PendingMetric "EnumerationError" }
            elseif (-not $complete -and $found.Count -lt $Wanted.Count) { Add-PendingMetric "EnumerationLimit" }
        }
    }
    return [pscustomobject]@{ Found=$found; Complete=$complete; Error=$errorText; Count=$count }
}

function Add-PendingDiscoveryAttribution {
    param([object[]]$Requests, [double]$ElapsedMs)
    # A shared directory read has no unique owner. Allocate its time by logical request count;
    # these values are explicitly labelled and are not added again to the global physical total.
    if ($null -eq $script:PendingPerformance -or $Requests.Count -eq 0) { return }
    foreach ($request in $Requests) {
        foreach ($dimension in @('ByPair', 'ByOperation')) {
            $key = if ($dimension -eq 'ByPair') { [string]$request.PairName } else { [string]$request.Operation }
            $map = $script:PendingPerformance.$dimension
            if (-not $map.ContainsKey($key)) { $map[$key] = @{ Counts=@{}; Milliseconds=@{} } }
            $map[$key].Milliseconds['AllocatedEnumeration'] = [double]$map[$key].Milliseconds['AllocatedEnumeration'] + $ElapsedMs / $Requests.Count
        }
    }
}

function Resolve-PendingDestinationObservations {
    param([object[]]$Requests)
    $results = @{}
    $directories = @{}
    foreach ($request in $Requests) {
        $directory = [System.IO.Path]::GetDirectoryName([string]$request.Destination)
        if (-not $directories.ContainsKey($directory)) { $directories[$directory] = [System.Collections.Generic.List[object]]::new() }
        $directories[$directory].Add($request)
    }
    if ($null -ne $script:PendingPerformance) { Add-PendingMetric "RequestedDirectories" 0 $directories.Count }
    foreach ($directory in $directories.Keys) {
        $group = $directories[$directory]
        $paths = @{}
        $wanted = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($request in $group) {
            $paths[$request.Destination] = $request
            [void]$wanted.Add([System.IO.Path]::GetFileName($request.Destination))
        }
        if ($null -ne $script:PendingPerformance) {
            $sizeBucket = if ($paths.Count -lt 8) { 'SparseDirectory' } else { 'DenseDirectory' }
            Add-PendingMetric $sizeBucket
            Add-PendingMetric 'DistinctDestinationPaths' 0 $paths.Count
        }
        $listing = $null
        if ($paths.Count -ge 8) {
            $started = if ($null -ne $script:PendingPerformance) { [Diagnostics.Stopwatch]::GetTimestamp() } else { 0 }
            $listing = Get-PendingDirectoryNames -Directory $directory -Limit ([math]::Max(1024, 4 * $paths.Count)) -Wanted $wanted
            if ($null -ne $script:PendingPerformance) {
                Add-PendingDiscoveryAttribution -Requests @($group.ToArray()) -ElapsedMs (([Diagnostics.Stopwatch]::GetTimestamp() - $started) * 1000.0 / [Diagnostics.Stopwatch]::Frequency)
            }
        }
        $pathResults = @{}
        $missingParent = $false
        $parentChecked = $false
        $negativePaths = [System.Collections.Generic.List[string]]::new()
        foreach ($destination in $paths.Keys) {
            $request = $paths[$destination]
            $name = [System.IO.Path]::GetFileName($destination)
            $state = "Error"; $method = "Exact"; $errorText = ""
            if ($null -ne $listing -and $listing.Found.Contains($name)) {
                $state = "Exists"; $method = "Enumeration"
            } elseif ($missingParent) {
                $state = "Missing"; $method = "MissingParent"
            } else {
                if ($null -ne $listing -and $null -ne $script:PendingPerformance) { Add-PendingMetric "EnumerationFallback" }
                $probe = Invoke-PendingPathProbe $destination "DestinationProbe" $request.PairName $request.Operation
                $state = [string]$probe.State; $errorText = [string]$probe.ErrorMessage
                if ($state -eq "Missing" -and -not $parentChecked -and $paths.Count -gt 1) {
                    $parentChecked = $true
                    $parent = Invoke-PendingPathProbe $directory "DestinationParentProbe" $request.PairName $request.Operation
                    $missingParent = ([string]$parent.State -eq "Missing")
                }
            }
            if ($state -eq "Missing") { $negativePaths.Add($destination) }
            $pathResults[$destination] = [pscustomobject]@{ State=$state; Method=$method; ErrorMessage=$errorText; CheckedUtc=[datetime]::UtcNow.ToString("o") }
        }
        # A failed/disconnected share can look like a missing path. Confirm its root AFTER negative probes.
        if ($negativePaths.Count -gt 0) {
            $first = $paths[$negativePaths[0]]
            $root = Invoke-PendingPathProbe $first.Root "DestinationRootConfirmation" $first.PairName $first.Operation
            if ($root.State -ne "Exists" -or -not $root.IsDirectory) {
                foreach ($destination in $negativePaths) {
                    $pathResults[$destination].State = "Error"
                    $pathResults[$destination].ErrorMessage = "Destination root unavailable"
                }
            }
        }
        foreach ($request in $group) {
            $result = $pathResults[$request.Destination]
            $results[$request.Key] = [pscustomobject]@{
                Id=$request.Id; Action=$request.Action; Destination=$request.Destination
                State=$result.State; Method=$result.Method; ErrorMessage=$result.ErrorMessage; CheckedUtc=$result.CheckedUtc
            }
            if ($null -ne $script:PendingPerformance) {
                Add-PendingMetric ("Observed" + $result.State) 0 1 $request.PairName $request.Operation
                Add-PendingMetric ("ResolvedBy" + $result.Method) 0 1 $request.PairName $request.Operation
            }
        }
    }
    return $results
}

function Get-PendingDestinationState {
    param([hashtable]$PreviousRootOnline = $null, [hashtable]$PairIndex = $null)
    if ($null -eq $PairIndex) { $PairIndex = Get-PendingPairIndex }
    $rootOnline = @{}; $pairOnline = @{}; $pairRoots = @{}; $becameOnline = @{}; $changedRoots = @{}
    $offlineRoots = [System.Collections.Generic.List[string]]::new()
    foreach ($pairKey in $PairIndex.Keys) {
        $root = [string]$PairIndex[$pairKey].Root
        $rootKey = $root.ToLowerInvariant()
        $pairRoots[$pairKey] = $rootKey
        if ([string]::IsNullOrWhiteSpace($rootKey)) { $pairOnline[$pairKey] = $false; continue }
        if (-not $rootOnline.ContainsKey($rootKey)) {
            $probe = Invoke-PendingPathProbe $root "RootProbe"
            $online = ($probe.State -eq "Exists" -and $probe.IsDirectory)
            $rootOnline[$rootKey] = $online
            if (-not $online) { $offlineRoots.Add($root.TrimEnd('\')) }
            $wasOnline = ($null -ne $PreviousRootOnline -and $PreviousRootOnline.ContainsKey($rootKey) -and [bool]$PreviousRootOnline[$rootKey])
            $becameOnline[$rootKey] = (-not $wasOnline -and $online)
            $changedRoots[$rootKey] = ($wasOnline -ne $online)
        }
        $pairOnline[$pairKey] = [bool]$rootOnline[$rootKey]
    }
    return [pscustomobject]@{
        RootOnline=$rootOnline; PairOnline=$pairOnline; PairRoots=$pairRoots; PairIndex=$PairIndex
        BecameOnline=$becameOnline; ChangedRoots=$changedRoots
        DriveStatus=[pscustomobject]@{ Online=($offlineRoots.Count -eq 0); OfflineDrives=@($offlineRoots.ToArray()) }
    }
}

function Save-PendingClassifications {
    param([object[]]$Classifications, [switch]$PassThru)
    if ($Classifications.Count -eq 0 -and -not $PassThru) { return $false }
    $mutex = Enter-QueueMutex
    if ($null -eq $mutex) {
        if ($PassThru) { throw "Pending classification timed out waiting for queue lock" }
        Write-Log "WARN" "Pending classification timed out waiting for queue lock"
        return $false
    }
    try {
        $dict = Get-QueueDictionary @(Read-QueueEntriesUnlocked)
        $changed = $false
        foreach ($wanted in $Classifications) {
            $key = [string]$wanted.Key
            if (-not $dict.ContainsKey($key)) { continue }
            $current = $dict[$key]
            if ([string]$current.Id -ne [string]$wanted.Id -or $current.Action -ne "Upsert") { continue }
            if ([string]$current.BaselineState -eq [string]$wanted.BaselineState -and [string]$current.Operation -eq [string]$wanted.Operation) { continue }
            $current.BaselineState = [string]$wanted.BaselineState
            $current.Operation = [string]$wanted.Operation
            $changed = $true
        }
        $currentEntries = @($dict.Values)
        if ($changed) {
            $written = Write-QueueEntriesUnlocked $currentEntries -PassThru
            if (-not $written.Success) { if ($PassThru) { throw "Pending classifications could not be saved" }; return $false }
            $currentEntries = @($written.Entries)
        }
        if ($PassThru) {
            # Entries and fingerprint are captured under the SAME mutex; callers need no third read.
            return [pscustomobject]@{ Changed=$changed; Entries=$currentEntries; QueueFingerprint=(Get-QueueFileFingerprint) }
        }
        return $changed
    } finally { Exit-QueueMutex $mutex }
}



function Get-ExactPathProbe {
    param([string]$Path)
    try {
        $attributes = [System.IO.File]::GetAttributes($Path)
        $isDirectory = (($attributes -band [System.IO.FileAttributes]::Directory) -ne 0)
        $item = if ($isDirectory) {
            [System.IO.DirectoryInfo]::new($Path)
        } else {
            [System.IO.FileInfo]::new($Path)
        }
        if ($null -eq $item) {
            return [pscustomobject]@{ State="Error"; Item=$null; IsDirectory=$null; ErrorMessage="EMPTY_PATH_RESULT" }
        }
        return [pscustomobject]@{ State="Exists"; Item=$item; IsDirectory=[bool]$isDirectory; ErrorMessage="" }
    } catch [System.IO.FileNotFoundException] {
        return [pscustomobject]@{ State="Missing"; Item=$null; IsDirectory=$null; ErrorMessage="" }
    } catch [System.IO.DirectoryNotFoundException] {
        return [pscustomobject]@{ State="Missing"; Item=$null; IsDirectory=$null; ErrorMessage="" }
    } catch [System.IO.DriveNotFoundException] {
        return [pscustomobject]@{ State="Missing"; Item=$null; IsDirectory=$null; ErrorMessage="" }
    } catch {
        return [pscustomobject]@{ State="Error"; Item=$null; IsDirectory=$null; ErrorMessage=(Format-ErrorSummary $_.Exception.Message) }
    }
}

function Sync-PendingDeleteEntries {
    param(
        [object[]]$Entries,
        [object]$DestinationState,
        [switch]$ReadOnly
    )
    $decisions = New-Object System.Collections.Generic.List[object]
    foreach ($entry in @($Entries)) {
        if ([string]$entry.Action -ne "Delete") { continue }
        $pairKey = ([string]$entry.PairName).ToUpperInvariant()
        $online = ($DestinationState.PairOnline.ContainsKey($pairKey) -and [bool]$DestinationState.PairOnline[$pairKey])
        if (-not $online) { continue }
        $context = $DestinationState.PairIndex[$pairKey]
        if ($null -eq $context) { continue }
        $pair = $context.Pair
        try { $paths=Get-SafeEntryPaths $pair $entry } catch { continue }
        $source=$paths.Source; $dest=$paths.Destination
        $sourceProbe = Invoke-PendingPathProbe $source "SourceProbe" $entry.PairName "Delete"
        if ([string]$sourceProbe.State -eq "Error") { continue }
        if ($sourceProbe.State -eq "Missing") {
            $sourceRootProbe = Invoke-PendingPathProbe $context.Source "SourceRootConfirmation" $entry.PairName "Delete"
            if ($sourceRootProbe.State -ne "Exists" -or -not $sourceRootProbe.IsDirectory) { continue }
        }
        $destProbe = Invoke-PendingPathProbe $dest "DestinationProbe" $entry.PairName "Delete"
        if ([string]$destProbe.State -eq "Error") { continue }
        if ($destProbe.State -eq "Missing") {
            $rootProbe = Invoke-PendingPathProbe $context.Root "DestinationRootConfirmation" $entry.PairName "Delete"
            if ($rootProbe.State -ne "Exists" -or -not $rootProbe.IsDirectory) { continue }
        }
        if ([string]$sourceProbe.State -eq "Exists") {
            $sourceItem = $sourceProbe.Item
            if ($null -eq $sourceItem) {
                Write-Log "WARN" ("Pending source probe returned no item; keeping entry queued: " + $source)
                continue
            }
            $isDirectory = [bool]$sourceProbe.IsDirectory
            $size = $(if ($isDirectory) { $null } else { [int64]$sourceItem.Length })
            $lastWrite = $(if ($isDirectory) { $null } else { $sourceItem.LastWriteTimeUtc.ToString("o") })
            $decisions.Add([pscustomobject]@{
                Kind = "Convert"
                Key = Get-QueueEntryKey $entry
                Id = [string]$entry.Id
                Source = $source
                Dest = $dest
                IsDirectory = $isDirectory
                Size = $size
                LastWriteTimeUtc = $lastWrite
                BaselineState = $(if ([string]$destProbe.State -eq "Exists") { "Present" } else { "Absent" })
                Operation = $(if ([string]$destProbe.State -eq "Exists") { "Update" } else { "Add" })
            }) | Out-Null
        } elseif ([string]$destProbe.State -eq "Missing") {
            $decisions.Add([pscustomobject]@{
                Kind = "Prune"
                Key = Get-QueueEntryKey $entry
                Id = [string]$entry.Id
            }) | Out-Null
        }
    }
    if ($decisions.Count -eq 0) {
        return [pscustomobject]@{ Changed=$false; Pruned=0; Converted=0; DirectoryEntries=@() }
    }

    $mutex = if ($ReadOnly) { $null } else { Enter-QueueMutex }
    if (-not $ReadOnly -and $null -eq $mutex) {
        Write-Log "WARN" "Pending delete reconciliation timed out waiting for queue lock"
        return [pscustomobject]@{ Changed=$false; Pruned=0; Converted=0; DirectoryEntries=@() }
    }
    try {
        $dict = if ($ReadOnly) { Get-QueueDictionary $Entries } else { Get-QueueDictionary @(Read-QueueEntriesUnlocked) }
        $pruned = 0
        $converted = 0
        $directoryEntries = New-Object System.Collections.Generic.List[object]
        foreach ($decision in @($decisions.ToArray())) {
            $key = [string]$decision.Key
            if (-not $dict.ContainsKey($key)) { continue }
            $current = $dict[$key]
            if ([string]$current.Id -ne [string]$decision.Id -or [string]$current.Action -ne "Delete") { continue }
            if ([string]$decision.Kind -eq "Prune") {
                $dict.Remove($key)
                $pruned++
                continue
            }
            $current.Action = "Upsert"
            $current.Operation = [string]$decision.Operation
            $current.EventKind = "Changed"
            $current.BaselineState = [string]$decision.BaselineState
            $current.TimeUtc = (Get-Date).ToUniversalTime().ToString("o")
            $current.Source = [string]$decision.Source
            $current.Dest = [string]$decision.Dest
            $current.IsDirectory = [bool]$decision.IsDirectory
            $current.Size = $decision.Size
            $current.LastWriteTimeUtc = $decision.LastWriteTimeUtc
            $dict[$key] = $current
            if ([bool]$current.IsDirectory) { $directoryEntries.Add($current) | Out-Null }
            $converted++
        }
        if (($pruned + $converted) -eq 0) {
            return [pscustomobject]@{ Changed=$false; Pruned=0; Converted=0; DirectoryEntries=@() }
        }
        if ($ReadOnly) {
            foreach ($directoryEntry in $directoryEntries) {
                $pair = Find-PairByName $directoryEntry.PairName
                foreach ($item in @(Get-SafeTreeItems $directoryEntry.Source $pair)) {
                    $child = New-QueueEntry $pair $item.FullName 'Upsert' $item.PSIsContainer -EventKind Snapshot
                    Merge-QueueEntryState $dict $child
                }
            }
            return [pscustomobject]@{Changed=$true;Pruned=$pruned;Converted=$converted;DirectoryEntries=@();Entries=@($dict.Values)}
        }
        if (-not (Write-QueueEntriesUnlocked @($dict.Values))) {
            return [pscustomobject]@{ Changed=$false; Pruned=0; Converted=0; DirectoryEntries=@() }
        }
        return [pscustomobject]@{ Changed=$true; Pruned=$pruned; Converted=$converted; DirectoryEntries=@($directoryEntries.ToArray()) }
    } finally {
        Exit-QueueMutex $mutex
    }
}

function Queue-ReconciledDirectorySnapshot {
    param([object]$Entry)
    $current = $null
    $mutex = Enter-QueueMutex
    if ($null -eq $mutex) {
        Write-Log "WARN" "Directory reconciliation timed out waiting for queue lock"
        return
    }
    try {
        $dict = Get-QueueDictionary @(Read-QueueEntriesUnlocked)
        $key = Get-QueueEntryKey $Entry
        if ($dict.ContainsKey($key) -and [string]$dict[$key].Id -eq [string]$Entry.Id -and [string]$dict[$key].Action -eq "Upsert") {
            $current = $dict[$key]
        }
    } finally {
        Exit-QueueMutex $mutex
    }
    if ($null -eq $current) { return }
    $sourceProbe = Get-ExactPathProbe ([string]$current.Source)
    if ([string]$sourceProbe.State -ne "Exists" -or $null -eq $sourceProbe.Item -or -not [bool]$sourceProbe.IsDirectory) { return }
    Queue-DirectorySnapshot -Entry $current -SkipRootMerge -ExpectedRootId ([string]$current.Id)
}

function Sync-PendingSessionSnapshot {
    param([switch]$RefreshDestinations, [switch]$ShowProgress, [switch]$ReadOnly)
    if ($ShowProgress) { Write-Host -NoNewline "Checking pending destinations..." -ForegroundColor Yellow }
    $scanStarted = [Diagnostics.Stopwatch]::GetTimestamp()
    $script:PendingScanActive = $true
    $script:PendingPerformance = if ($script:TracePendingPerformance) {
        [pscustomobject]@{
            StartedUtc=[datetime]::UtcNow.ToString("o"); Runtime=$PSVersionTable.PSVersion.ToString()
            TotalMs=0.0; Outcome="Error"; Entries=0; QueueBytes=0; Counts=@{}; Milliseconds=@{}; ByPair=@{}; ByOperation=@{}
        }
    } else { $null }
    try {
        $previous = $script:PendingSessionSnapshot
        $fingerprintBefore = Get-QueueFileFingerprint
        $queueChanged = ($null -eq $previous -or [string]$previous.QueueFingerprint -ne $fingerprintBefore)
        $pairIndex = Get-PendingPairIndex
        $contextIdentity = [string][bool]$ReadOnly + "|" + (@($pairIndex.Keys | Sort-Object | ForEach-Object {
            $_ + "|" + $pairIndex[$_].Source + "|" + $pairIndex[$_].Destination
        }) -join "`n")
        if ($null -ne $previous -and $previous.ContextIdentity -ne $contextIdentity) { $previous = $null; $queueChanged = $true }
        $previousHasDeletes = ($null -ne $previous -and [int]$previous.Counts.DeleteCount -gt 0)
        $previousRoots = if ($null -ne $previous) { $previous.RootOnline } else { $null }
        if ($RefreshDestinations -or $null -eq $previous -or $previousHasDeletes -or $previous.NeedsRefresh) {
            $destinationState = Get-PendingDestinationState -PreviousRootOnline $previousRoots -PairIndex $pairIndex
        } else {
            $destinationState = [pscustomobject]@{
                RootOnline=$previous.RootOnline; PairOnline=$previous.PairOnline; PairRoots=$previous.PairRoots
                PairIndex=$pairIndex; BecameOnline=@{}; ChangedRoots=@{}; DriveStatus=$previous.DriveStatus
            }
        }
        $rootsChanged = $false
        foreach ($value in $destinationState.ChangedRoots.Values) { if ($value) { $rootsChanged = $true; break } }
        if (-not $queueChanged -and $null -ne $previous -and -not $previousHasDeletes -and -not $rootsChanged -and -not $previous.NeedsRefresh) {
            $previous.RootOnline=$destinationState.RootOnline; $previous.PairOnline=$destinationState.PairOnline
            $previous.PairRoots=$destinationState.PairRoots; $previous.DriveStatus=$destinationState.DriveStatus
            if ($null -ne $script:PendingPerformance) {
                $script:PendingPerformance.Outcome="Snapshot"; $script:PendingPerformance.Entries=$previous.Entries.Count
                foreach ($entry in $previous.Entries) { Add-PendingMetric "SnapshotReuse" 0 1 $entry.PairName $entry.Operation }
            }
            return $previous
        }
        $entries = @(Remove-OrphanedUpserts @(Get-LatestQueueEntries @(Read-QueueEntries)))
        if ($null -ne $script:PendingPerformance) {
            foreach ($entry in $entries) { Add-PendingMetric 'QueuedEntries' 0 1 $entry.PairName $entry.Operation }
        }
        $deleteStarted = if ($null -ne $script:PendingPerformance) { [Diagnostics.Stopwatch]::GetTimestamp() } else { 0 }
        $deleteSync = Sync-PendingDeleteEntries -Entries $entries -DestinationState $destinationState -ReadOnly:$ReadOnly
        if ($null -ne $script:PendingPerformance) {
            Add-PendingMetric "DeleteReconciliation" $deleteStarted
            Add-PendingMetric "DeletesPruned" 0 $deleteSync.Pruned
            Add-PendingMetric "DeletesConverted" 0 $deleteSync.Converted
        }
        if ($deleteSync.Changed -and $ReadOnly) { $entries = @($deleteSync.Entries) }
        if ($deleteSync.Changed -and -not $ReadOnly) {
            Write-Log "QUEUE" ("Pending deletes reconciled: pruned={0} converted={1}" -f $deleteSync.Pruned, $deleteSync.Converted)
            foreach ($directoryEntry in $deleteSync.DirectoryEntries) {
                $started = if ($null -ne $script:PendingPerformance) { [Diagnostics.Stopwatch]::GetTimestamp() } else { 0 }
                Queue-ReconciledDirectorySnapshot $directoryEntry
                if ($null -ne $script:PendingPerformance) { Add-PendingMetric "RestoredDirectorySnapshot" $started 1 $directoryEntry.PairName "Delete" }
            }
            $entries = @(Remove-OrphanedUpserts @(Get-LatestQueueEntries @(Read-QueueEntries)))
        }
        $requests = [System.Collections.Generic.List[object]]::new()
        $observations = @{}
        $needsRefresh = $false
        foreach ($entry in $entries) {
            if ($entry.Action -eq "Delete") { $entry.Operation="Delete"; continue }
            $key = Get-QueueEntryKey $entry
            $pairKey = ([string]$entry.PairName).ToUpperInvariant()
            if (-not $pairIndex.ContainsKey($pairKey)) { continue }
            $context = $pairIndex[$pairKey]
            $destination = [System.IO.Path]::Combine($context.Destination, [string]$entry.RelPath)
            $online = [bool]$destinationState.PairOnline[$pairKey]
            if (-not $online) {
                # Queue event history is not proof of absence. Keep it unchanged and do not persist a guess.
                $observations[$key] = [pscustomobject]@{ Id=$entry.Id; Action=$entry.Action; Destination=$destination; State="Error"; Method="Offline"; ErrorMessage="Destination root unavailable"; CheckedUtc=[datetime]::UtcNow.ToString("o") }
                if ($null -ne $script:PendingPerformance) { Add-PendingMetric "OfflineEntries" 0 1 $entry.PairName $entry.Operation }
                continue
            }
            $old = if ($null -ne $previous -and $null -ne $previous.Observations -and $previous.Observations.ContainsKey($key)) { $previous.Observations[$key] } else { $null }
            $rootKey = [string]$destinationState.PairRoots[$pairKey]
            if ($null -ne $old -and $old.Id -eq $entry.Id -and $old.Action -eq $entry.Action -and $old.Destination -eq $destination -and $old.State -ne "Error" -and -not $destinationState.ChangedRoots[$rootKey]) {
                $observations[$key] = $old
                if ($null -ne $script:PendingPerformance) { Add-PendingMetric "SnapshotReuse" 0 1 $entry.PairName $entry.Operation }
                continue
            }
            $requests.Add([pscustomobject]@{ Key=$key; Id=$entry.Id; Action=$entry.Action; PairName=$entry.PairName; Operation=$entry.Operation; Destination=$destination; Root=$context.Root })
        }
        $resolved = Resolve-PendingDestinationObservations -Requests @($requests.ToArray())
        foreach ($key in $resolved.Keys) { $observations[$key] = $resolved[$key] }
        $classifications = [System.Collections.Generic.List[object]]::new()
        foreach ($entry in $entries) {
            if ($entry.Action -eq "Delete") { continue }
            $key = Get-QueueEntryKey $entry
            if (-not $observations.ContainsKey($key)) { continue }
            $observation = $observations[$key]
            if ($observation.State -eq "Error") { if ($observation.Method -ne "Offline") { $needsRefresh=$true }; continue }
            $baseline = if ($observation.State -eq "Exists") { "Present" } else { "Absent" }
            $operation = if ($observation.State -eq "Exists") { "Update" } else { "Add" }
            if ($entry.BaselineState -ne $baseline -or $entry.Operation -ne $operation) {
                $classifications.Add([pscustomobject]@{ Key=$key; Id=$entry.Id; BaselineState=$baseline; Operation=$operation })
            }
            $entry.BaselineState=$baseline; $entry.Operation=$operation
        }
        $commit = if ($ReadOnly) {
            [pscustomobject]@{ Entries=$entries; QueueFingerprint=$fingerprintBefore }
        } else { Save-PendingClassifications -Classifications @($classifications.ToArray()) -PassThru }
        $currentEntries = @(Remove-OrphanedUpserts $commit.Entries)
        $currentByKey = @{}
        foreach ($entry in $currentEntries) { $currentByKey[(Get-QueueEntryKey $entry)]=$entry }
        $stale = ($entries.Count -ne $currentEntries.Count)
        foreach ($entry in $entries) {
            $key = Get-QueueEntryKey $entry
            $current = $currentByKey[$key]
            if ($null -eq $current -or $entry.Id -ne $current.Id -or $entry.Action -ne $current.Action -or $entry.BaselineState -ne $current.BaselineState) { $stale=$true; break }
        }
        $fingerprintAfter = [string]$commit.QueueFingerprint
        if ($stale) { $fingerprintAfter="STALE|"+$fingerprintAfter }
        $counts = [pscustomobject]@{ EffectiveCount=$entries.Count; AddCount=0; UpdateCount=0; DeleteCount=0 }
        foreach ($entry in $entries) {
            switch ($entry.Operation) { "Add" { $counts.AddCount++ }; "Update" { $counts.UpdateCount++ }; "Delete" { $counts.DeleteCount++ } }
        }
        $snapshot = [pscustomobject]@{
            QueueFingerprint=$fingerprintAfter; ContextIdentity=$contextIdentity; Entries=$entries; Observations=$observations
            PairOnline=$destinationState.PairOnline; PairRoots=$destinationState.PairRoots; RootOnline=$destinationState.RootOnline
            DriveStatus=$destinationState.DriveStatus; Counts=$counts; NeedsRefresh=$needsRefresh; PreparedUtc=[datetime]::UtcNow.ToString("o")
        }
        $script:PendingSessionSnapshot=$snapshot
        if ($null -ne $script:PendingPerformance) { $script:PendingPerformance.Entries=$entries.Count; $script:PendingPerformance.Outcome=if($stale){"Stale"}else{"Prepared"} }
        return $snapshot
    } finally {
        $script:PendingScanActive=$false
        if ($null -ne $script:PendingPerformance) {
            $script:PendingPerformance.TotalMs=([Diagnostics.Stopwatch]::GetTimestamp()-$scanStarted)*1000.0/[Diagnostics.Stopwatch]::Frequency
            try { $script:PendingPerformance.QueueBytes=([System.IO.FileInfo]::new($script:QueuePath)).Length } catch {}
            $script:LastPendingPerformance=$script:PendingPerformance
            try { if (-not $ReadOnly) { Write-Log "PERF" ("Pending scan " + ($script:PendingPerformance | ConvertTo-Json -Depth 8 -Compress)) } } catch {}
            $script:PendingPerformance=$null
        }
        if ($ShowProgress) { Write-Host -NoNewline ("`r" + (" " * 40) + "`r") }
    }
}

function Write-QueueEntriesUnlocked {
    param([object[]]$Entries, [switch]$PassThru)
    $started = if ($null -ne $script:PendingPerformance) { [Diagnostics.Stopwatch]::GetTimestamp() } else { 0 }
    $effective = @(Get-LatestQueueEntries $Entries)
    $tmp = "$script:QueuePath.$PID.$([guid]::NewGuid().ToString('N')).tmp"
    $replaceBackup = "$script:QueuePath.$PID.replace.bak"
    $writer = $null
    try {
        $writer = New-Object System.IO.StreamWriter($tmp, $false, (New-Object System.Text.UTF8Encoding($false)))
        foreach ($entry in $effective) { $writer.WriteLine(($entry | ConvertTo-Json -Depth 10 -Compress)) }
        $writer.Dispose(); $writer = $null
        if (Test-Path -LiteralPath $script:QueuePath) { [System.IO.File]::Replace($tmp, $script:QueuePath, $replaceBackup) }
        else { Move-Item -LiteralPath $tmp -Destination $script:QueuePath -Force -ErrorAction Stop }
        try { Write-QueueMetaUnlocked $effective } catch { Write-Log "WARN" "Queue committed; metadata will be rebuilt: $($_.Exception.Message)" }
        if ($PassThru) { return [pscustomobject]@{ Success=$true; Entries=$effective } }
        return $true
    } catch {
        Write-Log "ERROR" "Rewrite queue failed: $($_.Exception.Message)"
        if ($PassThru) { return [pscustomobject]@{ Success=$false; Entries=@() } }
        return $false
    } finally {
        if ($null -ne $script:PendingPerformance) { Add-PendingMetric "QueueSave" $started }
        if ($null -ne $writer) { try { $writer.Dispose() } catch {} }
        if (Test-Path -LiteralPath $tmp) { Remove-OwnedPath ([IO.Path]::GetDirectoryName($tmp)) $tmp }
        if (Test-Path -LiteralPath $replaceBackup) { Remove-OwnedPath $script:DataDir $replaceBackup }
    }
}

function Write-QueueEntries {
    param([object[]]$Entries)
    $mutex = Enter-QueueMutex
    if ($null -eq $mutex) { Write-Log "ERROR" "Queue write timed out waiting for lock"; return $false }
    try { return (Write-QueueEntriesUnlocked $Entries) } finally { Exit-QueueMutex $mutex }
}

function Test-QueueMetaFresh {
    if (-not (Test-Path -LiteralPath $script:QueueMetaPath) -or -not (Test-Path -LiteralPath $script:QueuePath)) { return $false }
    try {
        $meta = Get-Content -LiteralPath $script:QueueMetaPath -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json
        $queueItem = Get-Item -LiteralPath $script:QueuePath -Force -ErrorAction Stop
        return ([int]$meta.SchemaVersion -eq 2 -and [int64]$meta.QueueLength -eq [int64]$queueItem.Length -and [int64]$meta.QueueWriteTicks -eq [int64]$queueItem.LastWriteTimeUtc.Ticks)
    } catch { return $false }
}

function Initialize-QueueStorage {
    if (Test-QueueMetaFresh) { return }
    $mutex = Enter-QueueMutex
    if ($null -eq $mutex) { throw "Queue initialization timed out waiting for lock" }
    try {
        if (Test-QueueMetaFresh) { return }
        $entries = @(Read-QueueEntriesUnlocked)
        $rawCount = $entries.Count
        if (Write-QueueEntriesUnlocked $entries) {
            $effectiveCount = @(Read-QueueEntriesUnlocked).Count
            Write-Log "QUEUE" "Queue v2 initialized: raw=$rawCount effective=$effectiveCount"
        }
    } finally { Exit-QueueMutex $mutex }
}

function Merge-QueueEntriesToDisk {
    param([object[]]$Entries)
    if (@($Entries).Count -eq 0) { return $true }
    $mutex = Enter-QueueMutex
    if ($null -eq $mutex) { Write-Log "WARN" "Queue merge timed out waiting for lock"; return $false }
    try {
        $pathIndex = @{}
        $dict = Get-QueueDictionary @(Read-QueueEntriesUnlocked) -PathIndex $pathIndex
        foreach ($entry in @($Entries)) { Merge-QueueEntryState -Dictionary $dict -Incoming $entry -PathIndex $pathIndex }
        return (Write-QueueEntriesUnlocked @($dict.Values))
    } finally { Exit-QueueMutex $mutex }
}

function Remove-AppliedQueueEntries {
    param([object[]]$AttemptedEntries, [string[]]$SuccessfulKeys)
    $success = @{}
    foreach ($key in @($SuccessfulKeys)) { $success[[string]$key] = $true }
    $attemptedByKey = @{}
    foreach ($entry in @($AttemptedEntries)) { $attemptedByKey[(Get-QueueEntryKey $entry)] = $entry }
    $mutex = Enter-QueueMutex
    if ($null -eq $mutex) { Write-Log "ERROR" "Queue apply cleanup timed out waiting for lock"; return $false }
    try {
        $dict = Get-QueueDictionary @(Read-QueueEntriesUnlocked)
        foreach ($key in @($success.Keys)) {
            if (-not $dict.ContainsKey($key) -or -not $attemptedByKey.ContainsKey($key)) { continue }
            if ([string]$dict[$key].Id -eq [string]$attemptedByKey[$key].Id) { $dict.Remove($key) }
        }
        return (Write-QueueEntriesUnlocked @($dict.Values))
    } finally { Exit-QueueMutex $mutex }
}

function Clear-PendingQueue {
    Show-Header "Clear Pending Queue" "This does not touch source or destination files"
    $entries = @(Read-QueueEntries)
    $latest = @(Get-LatestQueueEntries $entries)
    Write-Color ("Raw queued records      : " + $entries.Count) "Yellow"
    Write-Color ("Effective queued records: " + $latest.Count) "Yellow"
    Write-Host ""
    Write-Color "This only clears the saved change list. It does not copy, delete, or modify any files." "DarkGray"
    Write-Host ""
    if (-not (Read-EnterOrEsc "Press Enter to clear pending queue, or Esc to cancel.")) { return }
    Request-ClearPendingQueue
    Write-Color "Saved queue cleared. Watcher will acknowledge the cutoff; newer events are retained." "Green"
    Wait-Back
}

function Request-ClearPendingQueue {
    $cutoff=[datetime]::UtcNow
    $script:PendingSessionSnapshot=$null
    $mutex=Enter-QueueMutex
    if ($null -eq $mutex) { throw 'Clear queue lock timed out; queue preserved' }
    try {
        $entries=@(Read-QueueEntriesUnlocked)
        $keep=@($entries | Where-Object { ([datetimeoffset]::Parse((ConvertTo-UtcTimestamp $_.TimeUtc))).UtcDateTime -gt $cutoff })
        if (-not (Write-QueueEntriesUnlocked $keep)) { throw 'Clear queue failed' }
        Write-AtomicText $script:ClearQueueRequestPath $cutoff.ToString('o')
    } finally { Exit-QueueMutex $mutex }
    foreach ($key in @($script:Pending.Keys)) {
        if (([datetimeoffset]::Parse((ConvertTo-UtcTimestamp $script:Pending[$key].Entry.TimeUtc))).UtcDateTime -le $cutoff) { $script:Pending.Remove($key) }
    }
}

function Add-PendingEvent {
    param([object]$Entry)
    if ($null -eq $Entry) { return }
    $key = Get-QueueEntryKey $Entry
    $dict = @{}
    if ($script:Pending.ContainsKey($key)) { $dict[$key] = $script:Pending[$key].Entry }
    Merge-QueueEntryState -Dictionary $dict -Incoming $Entry
    if ($dict.ContainsKey($key)) {
        $script:Pending[$key] = [pscustomobject]@{ Entry = $dict[$key]; Due = (Get-Date).AddMilliseconds([int]$script:Config.DebounceMs) }
    } else {
        $script:Pending.Remove($key)
        if ([string]$Entry.Action -eq "Delete") {
            $cancel = ConvertTo-QueueV2Entry $Entry
            $cancel.BaselineState = "Absent"
            $cancel.Operation = "Delete"
            $script:Pending[$key] = [pscustomobject]@{ Entry = $cancel; Due = (Get-Date).AddMilliseconds([int]$script:Config.DebounceMs) }
        }
    }
}

function Normalize-QueueRelPath {
    param([string]$RelPath)
    $rel = ([string]$RelPath).Replace('/','\')
    if ([string]::IsNullOrWhiteSpace($rel) -or [IO.Path]::IsPathRooted($rel) -or $rel -match '[:*?"<>|\x00-\x1f]') { throw 'Invalid relative queue path' }
    foreach ($segment in $rel.Split('\')) {
        if (-not $segment -or $segment -in @('.','..') -or $segment -match '[. ]$' -or $segment -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)') { throw 'Unsafe relative queue path segment' }
    }
    return $rel
}

function Get-QueueEntryKey {
    param([object]$Entry)
    return (($Entry.PairName + "|" + (Normalize-QueueRelPath ([string]$Entry.RelPath))).ToUpperInvariant())
}

function Test-QueueEntryChildOf {
    param([object]$Entry, [object]$Parent)
    if ($null -eq $Entry -or $null -eq $Parent) { return $false }
    if ([string]$Entry.PairName -ine [string]$Parent.PairName) { return $false }
    $rel = Normalize-QueueRelPath ([string]$Entry.RelPath)
    $parentRel = Normalize-QueueRelPath ([string]$Parent.RelPath)
    if ([string]::IsNullOrWhiteSpace($rel) -or [string]::IsNullOrWhiteSpace($parentRel)) { return $false }
    if ($rel.Equals($parentRel, [System.StringComparison]::OrdinalIgnoreCase)) { return $false }
    return $rel.StartsWith(($parentRel + "\"), [System.StringComparison]::OrdinalIgnoreCase)
}



function Flush-PendingEvents {
    $now = Get-Date
    $dueEntries = New-Object System.Collections.Generic.List[object]
    $dueKeys = New-Object System.Collections.Generic.List[string]
    foreach ($key in @($script:Pending.Keys)) {
        $item = $script:Pending[$key]
        if ($item.Due -le $now) {
            $dueEntries.Add($item.Entry) | Out-Null
            $dueKeys.Add([string]$key) | Out-Null
        }
    }
    if ($dueEntries.Count -gt 0 -and (Merge-QueueEntriesToDisk @($dueEntries.ToArray()))) {
        foreach ($key in $dueKeys) { $script:Pending.Remove($key) }
        Write-Log "QUEUE" ("Committed {0} debounced decisions" -f $dueEntries.Count)
    }
}

function Process-ClearQueueRequest {
    if (-not [IO.File]::Exists($script:ClearQueueRequestPath)) { return }
    $mutex=Enter-QueueMutex
    if ($null -eq $mutex) { return }
    try {
        if (-not [IO.File]::Exists($script:ClearQueueRequestPath)) { return }
        $cutoff=[datetime]::Parse([IO.File]::ReadAllText($script:ClearQueueRequestPath),[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind)
        $keep=@(Read-QueueEntriesUnlocked | Where-Object { ([datetimeoffset]::Parse((ConvertTo-UtcTimestamp $_.TimeUtc))).UtcDateTime -gt $cutoff })
        if (-not (Write-QueueEntriesUnlocked $keep)) { throw 'Watcher could not acknowledge clear request' }
        foreach ($key in @($script:Pending.Keys)) {
            if (([datetimeoffset]::Parse((ConvertTo-UtcTimestamp $script:Pending[$key].Entry.TimeUtc))).UtcDateTime -le $cutoff) { $script:Pending.Remove($key) }
        }
        Remove-OwnedPath $script:DataDir $script:ClearQueueRequestPath
    } finally { Exit-QueueMutex $mutex }
}

function Merge-ReconciledDirectorySnapshotBatch {
    param(
        [object]$RootEntry,
        [string]$ExpectedRootId,
        [object[]]$Entries
    )
    $mutex = Enter-QueueMutex
    if ($null -eq $mutex) {
        Write-Log "WARN" "Directory snapshot batch timed out waiting for queue lock"
        return [pscustomobject]@{ Success=$false; ParentChanged=$false }
    }
    try {
        $pathIndex = @{}
        $dict = Get-QueueDictionary @(Read-QueueEntriesUnlocked) -PathIndex $pathIndex
        $rootKey = Get-QueueEntryKey $RootEntry
        if (-not $dict.ContainsKey($rootKey) -or [string]$dict[$rootKey].Id -ne $ExpectedRootId -or [string]$dict[$rootKey].Action -ne "Upsert") {
            return [pscustomobject]@{ Success=$false; ParentChanged=$true }
        }
        foreach ($entry in @($Entries)) { Merge-QueueEntryState -Dictionary $dict -Incoming $entry -PathIndex $pathIndex }
        return [pscustomobject]@{ Success=[bool](Write-QueueEntriesUnlocked @($dict.Values)); ParentChanged=$false }
    } finally {
        Exit-QueueMutex $mutex
    }
}

function Queue-DirectorySnapshot {
    param([object]$Entry, [switch]$SkipRootMerge, [string]$ExpectedRootId = "")
    if (-not [bool]$Entry.IsDirectory) { return }
    $pair = Find-PairByName $Entry.PairName
    if ($null -eq $pair) { return }
    if (!(Test-Path -LiteralPath $Entry.Source -PathType Container)) { return }
    if (-not $SkipRootMerge -and -not (Merge-QueueEntriesToDisk @($Entry))) { Write-Log "ERROR" "Could not commit directory root before snapshot"; return }
    $script:Pending.Remove((Get-QueueEntryKey $Entry))
    $count = 0
    $parentChanged = $false
    $batch = New-Object System.Collections.Generic.List[object]
    try {
        Get-SafeTreeItems $Entry.Source $pair |
            Select-Object -First ([int]$script:Config.DirectoryScanMaxItems) |
            ForEach-Object {
                if (Test-Excluded -Pair $pair -FullPath $_.FullName -IsDirectory $_.PSIsContainer) { return }
                $baseline = $(if ([string]$Entry.BaselineState -eq "Absent") { "Absent" } else { "Unknown" })
                $qe = New-QueueEntry -Pair $pair -FullPath $_.FullName -Action "Upsert" -KnownIsDirectory ([bool]$_.PSIsContainer) -EventKind "Snapshot" -BaselineState $baseline
                if ($null -ne $qe) { $batch.Add($qe) | Out-Null }
                $count++
                if ($batch.Count -ge 1000) {
                    if ([string]::IsNullOrWhiteSpace($ExpectedRootId)) {
                        if (-not (Merge-QueueEntriesToDisk @($batch.ToArray()))) { throw "Could not commit directory snapshot batch" }
                    } else {
                        $commit = Merge-ReconciledDirectorySnapshotBatch -RootEntry $Entry -ExpectedRootId $ExpectedRootId -Entries @($batch.ToArray())
                        if ([bool]$commit.ParentChanged) { $parentChanged = $true; throw [System.OperationCanceledException]::new("Directory snapshot root event changed") }
                        if (-not [bool]$commit.Success) { throw "Could not commit reconciled directory snapshot batch" }
                    }
                    $batch.Clear()
                }
            }
        if ($batch.Count -gt 0) {
            if ([string]::IsNullOrWhiteSpace($ExpectedRootId)) {
                if (-not (Merge-QueueEntriesToDisk @($batch.ToArray()))) { throw "Could not commit directory snapshot batch" }
            } else {
                $commit = Merge-ReconciledDirectorySnapshotBatch -RootEntry $Entry -ExpectedRootId $ExpectedRootId -Entries @($batch.ToArray())
                if ([bool]$commit.ParentChanged) { Write-Log "SCAN" "Directory snapshot stopped because the root event changed: $($Entry.PairName) :: $($Entry.RelPath)"; return }
                if (-not [bool]$commit.Success) { throw "Could not commit reconciled directory snapshot batch" }
            }
        }
        if ($count -ge [int]$script:Config.DirectoryScanMaxItems) { Write-Log 'WARN' 'Directory child snapshot limit reached; root tree job is retained for complete transfer' }
        Write-Log "SCAN" "Queued directory snapshot for $($Entry.PairName) :: $($Entry.RelPath) :: $count items"
    } catch {
        if ($parentChanged) {
            Write-Log "SCAN" "Directory snapshot stopped because the root event changed: $($Entry.PairName) :: $($Entry.RelPath)"
        } else {
            Write-Log "ERROR" "Directory snapshot failed: $($_.Exception.Message)"
        }
    }
}

function Start-Watcher {
    Show-Header "Watch Changes" "Queue only - no automatic copy"
    $pairs = @(Get-Pairs)
    if ($pairs.Count -eq 0) {
        Write-Color "No backup pairs configured. Add a pair first." "Yellow"
        Wait-Back
        return
    }

    $mutexName = $script:QueueMutexName.Replace("MiraQueueQueue_", "MiraQueueWatcher_")
    $script:Mutex = New-Object System.Threading.Mutex($false, $mutexName)
    $watcherMutexAcquired = $false
    try {
        $watcherMutexAcquired = $script:Mutex.WaitOne(0, $false)
    } catch [System.Threading.AbandonedMutexException] {
        $watcherMutexAcquired = $true
    }
    if (-not $watcherMutexAcquired) {
        $script:Mutex.Dispose(); $script:Mutex=$null
        Write-Color "Another watcher instance is already running." "Red"
        Wait-Back
        return
    }

    if ([IO.File]::Exists($script:StopWatcherRequestPath)) { Remove-OwnedPath $script:DataDir $script:StopWatcherRequestPath }
    Write-Color "Watching configured sources. Changes are stored until you apply them." "DarkGray"
    Write-Color "Press Ctrl+C to stop." "DarkGray"
    Write-Host ""

    $watchers = New-Object System.Collections.Generic.List[object]
    $subscriptions = New-Object System.Collections.Generic.List[object]
    try {
        for ($i = 0; $i -lt $pairs.Count; $i++) {
            $pair = $pairs[$i]
            Assert-PairLayout $pair
            if (!(Test-Path -LiteralPath $pair.Source -PathType Container)) {
                Write-Color ("Missing source, skipped: " + $pair.Source) "DarkYellow"
                Write-Log "WARN" "Missing source skipped: $($pair.Name)"
                continue
            }
            $fsw = New-Object System.IO.FileSystemWatcher
            $fsw.Path = $pair.Source
            $fsw.IncludeSubdirectories = $true
            $fsw.InternalBufferSize = [Math]::Min(65536, [Math]::Max(4096, [int]$script:Config.WatchBufferKB * 1024))
            $fsw.NotifyFilter = [System.IO.NotifyFilters]'FileName, DirectoryName, LastWrite, Size, CreationTime'
            foreach ($ev in @("Created","Changed","Deleted","Renamed","Error")) {
                $srcId = "MQ|$i|$ev"
                $sub = Register-ObjectEvent -InputObject $fsw -EventName $ev -SourceIdentifier $srcId
                $subscriptions.Add($sub) | Out-Null
            }
            $fsw.EnableRaisingEvents = $true
            $watchers.Add($fsw) | Out-Null
            Write-Color ("Watching: {0} -> {1}" -f $pair.Source, (Resolve-DestinationPath $pair.Dest)) "Gray"
        }
        while ($true) {
            $evt = Wait-Event -Timeout 1
            if ($evt -ne $null) {
                Process-WatcherEvent $evt
                Remove-Event -EventIdentifier $evt.EventIdentifier -ErrorAction SilentlyContinue
            }
            foreach ($queuedEvt in @(Get-Event)) {
                Process-WatcherEvent $queuedEvt
                Remove-Event -EventIdentifier $queuedEvt.EventIdentifier -ErrorAction SilentlyContinue
            }
            if ([IO.File]::Exists($script:StopWatcherRequestPath)) {
                Remove-OwnedPath $script:DataDir $script:StopWatcherRequestPath
                break
            }
            Process-ClearQueueRequest
            Flush-PendingEvents
        }
    } finally {
        foreach ($pendingItem in $script:Pending.Values) { $pendingItem.Due=[datetime]::MinValue }
        try { Flush-PendingEvents } catch { Write-Log "ERROR" "Watcher shutdown flush failed; run Full Mirror preview" }
        foreach ($subscription in $subscriptions) { try { Unregister-Event -SubscriptionId $subscription.SubscriptionId -ErrorAction Stop } catch { Write-Log "WARN" "Event unsubscribe failed: $($_.Exception.Message)" } }
        foreach ($w in $watchers) { try { $w.EnableRaisingEvents = $false; $w.Dispose() } catch {} }
        if ($script:Mutex) { try { $script:Mutex.ReleaseMutex() | Out-Null; $script:Mutex.Dispose() } catch {} }
    }
}

function Process-WatcherEvent {
    param([object]$Evt)
    try {
        $parts = $Evt.SourceIdentifier -split '\|'
        if ($parts.Count -lt 3) { return }
        $idx = [int]$parts[1]
        $eventName = $parts[2]
        $pairs = @(Get-Pairs)
        if ($idx -lt 0 -or $idx -ge $pairs.Count) { return }
        $pair = $pairs[$idx]
        $args = $Evt.SourceEventArgs
        if ($eventName -eq 'Error') { Write-Log 'ERROR' 'Watcher overflow or source error: run Full Mirror preview to recover missed changes'; return }
        $path = $args.FullPath
        if (-not (Test-PathInsideRoot $pair.Source $path)) { return }
        Assert-NoReparsePath $path
        if ($eventName -eq "Renamed") {
            $oldPath = $args.OldFullPath
            $newPathExcluded = Test-Excluded -Pair $pair -FullPath $path
            $pathOk = $false
            $renamedIsDir = $null
            if (-not $newPathExcluded) {
                $maxRetries = 10
                $retry = 0
                do {
                    if ($retry -gt 0) { Start-Sleep -Milliseconds 300 }
                    $pathOk = Test-Path -LiteralPath $path -ErrorAction SilentlyContinue
                    $retry++
                } while (-not $pathOk -and $retry -lt $maxRetries)
                if ($pathOk) {
                    $renamedIsDir = Test-Path -LiteralPath $path -PathType Container
                }
            }
            if (-not (Test-Excluded -Pair $pair -FullPath $oldPath)) {
                if ($renamedIsDir -ne $null) {
                    Add-PendingEvent (New-QueueEntry -Pair $pair -FullPath $oldPath -Action "Delete" -KnownIsDirectory ([bool]$renamedIsDir) -EventKind "RenamedOld" -BaselineState "Present")
                } else {
                    Add-PendingEvent (New-QueueEntry -Pair $pair -FullPath $oldPath -Action "Delete" -EventKind "RenamedOld" -BaselineState "Present")
                }
            }
            if (-not $newPathExcluded) {
                if ($renamedIsDir -ne $null) {
                    $entry = New-QueueEntry -Pair $pair -FullPath $path -Action "Upsert" -KnownIsDirectory ([bool]$renamedIsDir) -EventKind "RenamedNew" -BaselineState "Unknown"
                } else {
                    $entry = New-QueueEntry -Pair $pair -FullPath $path -Action "Upsert" -EventKind "RenamedNew" -BaselineState "Unknown"
                }
                Add-PendingEvent $entry
                if ($pathOk) {
                    if ([bool]$renamedIsDir) {
                        Write-Log "SCAN" ("Renamed dir: $path")
                        $scanEntry = New-QueueEntry -Pair $pair -FullPath $path -Action "Upsert" -KnownIsDirectory $true -EventKind "RenamedNew" -BaselineState "Unknown"
                        Queue-DirectorySnapshot $scanEntry
                    }
                } else {
                    Write-Log "WARN" ("New path not available after rename: $path")
                }
            }
            return
        }
        if (Test-Excluded -Pair $pair -FullPath $path) { return }
        if ($eventName -eq "Deleted") {
            Add-PendingEvent (New-QueueEntry -Pair $pair -FullPath $path -Action "Delete" -EventKind "Deleted" -BaselineState "Present")
        } elseif ($eventName -eq "Created") {
            if (!(Test-Path -LiteralPath $path)) { return }
            $isDir = Test-Path -LiteralPath $path -PathType Container
            $entry = New-QueueEntry -Pair $pair -FullPath $path -Action "Upsert" -KnownIsDirectory $isDir -EventKind "Created" -BaselineState "Unknown"
            Add-PendingEvent $entry
            if ($isDir) {
                $maxRetries = 10
                $retry = 0
                do {
                    if ($retry -gt 0) { Start-Sleep -Milliseconds 300 }
                    $pathOk = Test-Path -LiteralPath $path -ErrorAction SilentlyContinue
                    $retry++
                } while (-not $pathOk -and $retry -lt $maxRetries)
                if ($pathOk) {
                    Write-Log "SCAN" ("Created dir: $path")
                    $scanEntry = New-QueueEntry -Pair $pair -FullPath $path -Action "Upsert" -KnownIsDirectory $true -EventKind "Created" -BaselineState "Unknown"
                    Queue-DirectorySnapshot $scanEntry
                } else {
                    Write-Log "WARN" ("Created dir not available for snapshot: $path")
                }
            }
        } else {
            if (!(Test-Path -LiteralPath $path)) { return }
            $isDir = Test-Path -LiteralPath $path -PathType Container
            if ($isDir) { return }
            Add-PendingEvent (New-QueueEntry -Pair $pair -FullPath $path -Action "Upsert" -KnownIsDirectory $isDir -EventKind "Changed" -BaselineState "Present")
        }
    } catch {
        Write-Log "ERROR" "Process event failed: $($_.Exception.Message)"
    }
}

function Test-FileNeedsCopy {
    param(
        [string]$Source,
        [string]$Dest,
        [object]$SourceItem = $null
    )
    if (!(Test-Path -LiteralPath $Dest)) { return $true }
    try {
        $s = if ($null -ne $SourceItem) { $SourceItem } else { Get-Item -LiteralPath $Source -Force }
        $d = Get-Item -LiteralPath $Dest -Force
        if ($s.Length -ne $d.Length) { return $true }
        $diff = [Math]::Abs(($s.LastWriteTimeUtc - $d.LastWriteTimeUtc).TotalSeconds)
        return ($diff -gt [double]$script:Config.TimeToleranceSeconds)
    } catch {
        return $true
    }
}

function Copy-FileStreamWithProgress {
    param(
        [string]$Source,
        [string]$Destination,
        [scriptblock]$ProgressCallback = $null,
        [object]$SourceItem = $null
    )
    $sourceItem = if ($null -ne $SourceItem) { $SourceItem } else { Get-Item -LiteralPath $Source -Force -ErrorAction Stop }
    $total = [int64]$sourceItem.Length
    $copied = [int64]0
    if ($ProgressCallback) { & $ProgressCallback $copied $total }

    $bufferSize = 1024 * 1024
    $buffer = New-Object byte[] $bufferSize
    $inputStream = $null
    $outputStream = $null
    try {
        $inputStream = [System.IO.File]::Open($Source, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        $outputStream = [System.IO.File]::Open($Destination, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        while ($true) {
            $read = $inputStream.Read($buffer, 0, $buffer.Length)
            if ($read -le 0) { break }
            $outputStream.Write($buffer, 0, $read)
            $copied += [int64]$read
            if ($ProgressCallback) { & $ProgressCallback $copied $total }
        }
        $outputStream.Flush()
    } finally {
        if ($outputStream) { $outputStream.Dispose() }
        if ($inputStream) { $inputStream.Dispose() }
    }
    if ($ProgressCallback -and $copied -ne $total) { & $ProgressCallback $total $total }
    return [int64]$copied
}

function Copy-FileSafe {
    param(
        [string]$Source,
        [string]$Dest,
        [scriptblock]$ProgressCallback = $null,
        [object]$SourceItem = $null
    )
    $sourceItem = if ($null -ne $SourceItem) { $SourceItem } else { Get-Item -LiteralPath $Source -Force -ErrorAction Stop }
    Assert-NoReparsePath $Source
    Assert-NoReparsePath $Dest
    $destDir = Split-Path -Parent $Dest
    if (!(Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    $copied = [int64]0
    if ([bool]$script:Config.CopyTempThenReplace) {
        $name = Split-Path -Leaf $Dest
        $tmp = Join-Path $destDir (".$name.mqtmp-$([guid]::NewGuid().ToString('N'))")
        $backup = $null
        try {
            $copied = Copy-FileStreamWithProgress -Source $Source -Destination $tmp -ProgressCallback $ProgressCallback -SourceItem $sourceItem
            if ([bool]$script:Config.PreserveModifiedTime) {
                try { (Get-Item -LiteralPath $tmp -Force).LastWriteTimeUtc = $sourceItem.LastWriteTimeUtc } catch {}
            }
            if (Test-Path -LiteralPath $Dest -PathType Leaf) {
                $destItem = Get-Item -LiteralPath $Dest -Force -ErrorAction Stop
                if ($destItem.Attributes -band [System.IO.FileAttributes]::ReadOnly) {
                    $destItem.Attributes = $destItem.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly)
                }
                $backup = Join-Path $destDir (".$name.mqbackup-$([guid]::NewGuid().ToString('N'))")
                [System.IO.File]::Replace($tmp, $Dest, $backup)
                try { if ([System.IO.File]::Exists($backup)) { [System.IO.File]::Delete($backup) } } catch {}
                if (-not [System.IO.File]::Exists($backup)) { $backup = $null }
            } else {
                [System.IO.File]::Move($tmp, $Dest)
            }
            $tmp = $null
        } finally {
            if (-not [string]::IsNullOrWhiteSpace($tmp) -and (Test-Path -LiteralPath $tmp)) {
                Remove-OwnedPath ([IO.Path]::GetDirectoryName($tmp)) $tmp
            }
            if (-not [string]::IsNullOrWhiteSpace($backup) -and (Test-Path -LiteralPath $backup)) {
                Remove-OwnedPath ([IO.Path]::GetDirectoryName($backup)) $backup
            }
        }
    } else {
        $copied = Copy-FileStreamWithProgress -Source $Source -Destination $Dest -ProgressCallback $ProgressCallback -SourceItem $sourceItem
        if ([bool]$script:Config.PreserveModifiedTime) {
            try { (Get-Item -LiteralPath $Dest -Force).LastWriteTimeUtc = $sourceItem.LastWriteTimeUtc } catch {}
        }
    }
    if ([bool]$script:Config.CopyAttributes) {
        try { (Get-Item -LiteralPath $Dest -Force).Attributes = $sourceItem.Attributes } catch {}
    }
    return [pscustomobject]@{
        BytesCopied = [int64]$copied
        TotalBytes = [int64]$sourceItem.Length
    }
}

function Apply-OneEntry {
    param(
        [object]$Entry,
        [scriptblock]$ProgressCallback = $null,
        [Nullable[bool]]$DestinationOnline = $null,
        [object]$PairOverride = $null,
        [switch]$MissingOnly,
        [switch]$MirrorDelete
    )
    $pair = if ($null -ne $PairOverride) { $PairOverride } else { Find-PairByName $Entry.PairName }
    if ($null -eq $pair) { return [pscustomobject]@{ Pair=$Entry.PairName; Action=$Entry.Action; Path=$Entry.RelPath; Status="FAILED"; Message="Pair not found" } }
    $isOnline = if ($DestinationOnline -ne $null) { [bool]$DestinationOnline } else { Test-DestRootAvailable $pair.Dest }
    if (-not $isOnline) { return [pscustomobject]@{ Pair=$pair.Name; Action="SKIP"; Path=$Entry.RelPath; Status="SKIPPED"; Message="Destination drive offline" } }
    $dstRoot = Resolve-DestinationPath $pair.Dest
    try {
        $paths = Get-SafeEntryPaths $pair $Entry
        $source=$paths.Source; $dest=$paths.Destination
        if (Test-Excluded $pair $source ([bool]$Entry.IsDirectory)) {
            return [pscustomobject]@{ Pair=$pair.Name; Action=$Entry.Action; Path=$Entry.RelPath; Status='SKIPPED'; Message='Excluded by current configuration'; RetainPending=$true }
        }
        if ($Entry.Action -eq "Delete") {
            if (-not $MirrorDelete -and -not [bool]$script:Config.DeleteDestOnSourceDelete) {
                return [pscustomobject]@{ Pair=$pair.Name; Action="DELETE"; Path=$Entry.RelPath; Status="SKIPPED"; Message="Delete disabled"; RetainPending=$true }
            }
            $sourceProbe = Get-ExactPathProbe $source
            if ([string]$sourceProbe.State -ne "Missing") {
                $message = $(if ([string]$sourceProbe.State -eq "Exists") { "Source restored; delete canceled" } else { "Source check failed; delete canceled" })
                return [pscustomobject]@{ Pair=$pair.Name; Action="DELETE"; Path=$Entry.RelPath; Status="SKIPPED"; Message=$message; RetainPending=$true; ResultKind="DeleteCanceled" }
            }
            # Missing source media/root is not evidence that the user deleted this entry.
            $sourceRootProbe = Get-ExactPathProbe ([string]$pair.Source)
            if ($sourceRootProbe.State -ne "Exists" -or -not $sourceRootProbe.IsDirectory) {
                return [pscustomobject]@{ Pair=$pair.Name; Action="DELETE"; Path=$Entry.RelPath; Status="SKIPPED"; Message="Source root unavailable; delete canceled"; RetainPending=$true; ResultKind="DeleteCanceled" }
            }
            $destProbe = Get-ExactPathProbe $dest
            if ([string]$destProbe.State -eq "Exists") {
                Remove-VerifiedDestination $pair ([string]$Entry.RelPath)
                return [pscustomobject]@{ Pair=$pair.Name; Action="DELETE"; Path=$Entry.RelPath; Status="OK"; Message="" }
            }
            if ([string]$destProbe.State -eq "Error") {
                return [pscustomobject]@{ Pair=$pair.Name; Action="DELETE"; Path=$Entry.RelPath; Status="SKIPPED"; Message="Destination drive offline"; RetainPending=$true; ResultKind="DestinationIndeterminate" }
            }
            $destRoot = [string][System.IO.Path]::GetPathRoot($dstRoot)
            $destRootProbe = Get-ExactPathProbe $destRoot
            if ([string]::IsNullOrWhiteSpace($destRoot) -or [string]$destRootProbe.State -ne "Exists") {
                return [pscustomobject]@{ Pair=$pair.Name; Action="DELETE"; Path=$Entry.RelPath; Status="SKIPPED"; Message="Destination drive offline"; RetainPending=$true; ResultKind="DestinationIndeterminate" }
            }
            return [pscustomobject]@{ Pair=$pair.Name; Action="DELETE"; Path=$Entry.RelPath; Status="SKIPPED"; Message="Destination missing"; ResultKind="ObsoleteDelete" }
        }
        $sourceProbe=Get-ExactPathProbe $source
        $destProbe=Get-ExactPathProbe $dest
        if ($sourceProbe.State -eq 'Error' -or $destProbe.State -eq 'Error') { throw 'Path check failed' }
        if ($sourceProbe.State -eq 'Exists' -and [bool]$sourceProbe.IsDirectory -ne [bool]$Entry.IsDirectory) { throw 'Source kind changed; rescan required' }
        if ($destProbe.State -eq 'Exists' -and [bool]$destProbe.IsDirectory -ne [bool]$Entry.IsDirectory) { throw 'Source/destination type conflict; review required' }
        if ($MissingOnly -and $destProbe.State -eq 'Exists') { return [pscustomobject]@{Pair=$pair.Name;Action='COPY';Path=$Entry.RelPath;Status='SKIPPED';Message='Existing destination preserved'} }
        if ($sourceProbe.State -ne 'Exists') {
            return [pscustomobject]@{ Pair=$pair.Name; Action="COPY"; Path=$Entry.RelPath; Status="FAILED"; Message="Source missing" }
        }
        if ($Entry.IsDirectory) {
            if (Test-Path -LiteralPath $dest -PathType Container) {
                return [pscustomobject]@{ Pair=$pair.Name; Action="MKDIR"; Path=$Entry.RelPath; Status="SKIPPED"; Message="Directory exists" }
            }
            [IO.Directory]::CreateDirectory($dest) | Out-Null
            return [pscustomobject]@{ Pair=$pair.Name; Action="MKDIR"; Path=$Entry.RelPath; Status="OK"; Message="" }
        }
        $sourceItem = Get-Item -LiteralPath $source -Force -ErrorAction Stop
        if (Test-FileNeedsCopy -Source $source -Dest $dest -SourceItem $sourceItem) {
            $copyInfo = Copy-FileSafe -Source $source -Dest $dest -ProgressCallback $ProgressCallback -SourceItem $sourceItem
            return [pscustomobject]@{ Pair=$pair.Name; Action="COPY"; Path=$Entry.RelPath; Status="OK"; Message=""; BytesCopied=[int64]$copyInfo.BytesCopied; TotalBytes=[int64]$copyInfo.TotalBytes }
        }
        return [pscustomobject]@{ Pair=$pair.Name; Action="COPY"; Path=$Entry.RelPath; Status="SKIPPED"; Message="Already current"; BytesCopied=[int64]$sourceItem.Length; TotalBytes=[int64]$sourceItem.Length }
    } catch {
        return [pscustomobject]@{ Pair=$pair.Name; Action=$Entry.Action.ToUpperInvariant(); Path=$Entry.RelPath; Status="FAILED"; Message=$_.Exception.Message; RetainPending=$true }
    }
}

function Get-ApplyProgressStartingStatus {
    param([object]$Entry)
    if ($Entry.Action -eq "Delete") { return "DELETE" }
    if ([bool]$Entry.IsDirectory) { return "MKDIR" }
    return "COPYING"
}

function Get-ApplyProgressFinalStatus {
    param([object]$Result)
    if ($null -eq $Result) { return "FAILED" }
    if ($Result.Status -eq "FAILED") { return "FAILED" }
    if ($Result.Status -eq "SKIPPED") { return "SKIPPED" }
    if ($Result.Action -eq "DELETE") { return "DELETE" }
    if ($Result.Action -eq "MKDIR") { return "MKDIR" }
    return "DONE"
}

function Get-QueuePathDepth {
    param([string]$RelPath)
    $normalized = Normalize-QueueRelPath $RelPath
    if ([string]::IsNullOrWhiteSpace($normalized)) { return 0 }
    return @($normalized.Split('\')).Count
}

function Get-DirectoryTransferTotalBytes {
    param([object]$Entry)
    $pair = Find-PairByName ([string]$Entry.PairName)
    if ($null -eq $pair) {
        return [pscustomobject]@{ Known=$false; TotalBytes=[int64]0 }
    }
    $source = Join-PathSafe ([string]$pair.Source) ([string]$Entry.RelPath)
    if ([string]::IsNullOrWhiteSpace($source) -or -not (Test-Path -LiteralPath $source -PathType Container)) {
        return [pscustomobject]@{ Known=$false; TotalBytes=[int64]0 }
    }
    try {
        $totalBytes = [int64]0
        $pendingDirectories = [System.Collections.Generic.Stack[System.IO.DirectoryInfo]]::new()
        $pendingDirectories.Push([System.IO.DirectoryInfo]::new($source))
        while ($pendingDirectories.Count -gt 0) {
            $directory = $pendingDirectories.Pop()
            foreach ($item in @(Get-ChildItem -LiteralPath $directory.FullName -Force -ErrorAction Stop)) {
                if ($item.PSIsContainer) {
                    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
                    if (Test-Excluded -Pair $pair -FullPath $item.FullName -IsDirectory $true) { continue }
                    $pendingDirectories.Push([System.IO.DirectoryInfo]$item)
                } elseif (-not (Test-Excluded -Pair $pair -FullPath $item.FullName -IsDirectory $false)) {
                    $totalBytes += [int64]$item.Length
                }
            }
        }
        return [pscustomobject]@{ Known=$true; TotalBytes=$totalBytes }
    } catch {
        Write-Log "WARN" ("Could not measure pending directory size: {0} :: {1}" -f $source, (Format-ErrorSummary $_.Exception.Message))
        return [pscustomobject]@{ Known=$false; TotalBytes=[int64]0 }
    }
}

function Get-ApplyExecutionPlan {
    param([object[]]$Entries)
    $allEntries = @($Entries)
    $coveredKeys = @{}
    $directoryJobs = New-Object System.Collections.Generic.List[object]
    $candidates = @($allEntries | Where-Object {
        $_.Action -eq "Upsert" -and [bool]$_.IsDirectory
    } | Sort-Object @{Expression={ Get-QueuePathDepth ([string]$_.RelPath) }}, PairName, RelPath)

    foreach ($root in $candidates) {
        $rootKey = Get-QueueEntryKey $root
        if ($coveredKeys.ContainsKey($rootKey)) { continue }
        $covered = @($allEntries | Where-Object {
            $_.Action -eq "Upsert" -and
            ((Get-QueueEntryKey $_) -eq $rootKey -or (Test-QueueEntryChildOf -Entry $_ -Parent $root))
        })
        foreach ($entry in $covered) { $coveredKeys[(Get-QueueEntryKey $entry)] = $true }
        $sizeMeasurement = Get-DirectoryTransferTotalBytes $root
        $root | Add-Member -NotePropertyName "CoveredCount" -NotePropertyValue $covered.Count -Force
        if ([bool]$sizeMeasurement.Known) {
            $root | Add-Member -NotePropertyName "CoveredTotalBytes" -NotePropertyValue ([int64]$sizeMeasurement.TotalBytes) -Force
        } elseif ($null -ne $root.PSObject.Properties["CoveredTotalBytes"]) {
            $root.PSObject.Properties.Remove("CoveredTotalBytes")
        }
        $directoryJobs.Add([pscustomobject]@{ Root=$root; Entries=$covered }) | Out-Null
    }

    $deletes = @($allEntries | Where-Object Action -eq "Delete" |
        Sort-Object @{Expression={ Get-QueuePathDepth ([string]$_.RelPath) };Descending=$true}, PairName, RelPath)
    $files = @($allEntries | Where-Object {
        $_.Action -eq "Upsert" -and -not [bool]$_.IsDirectory -and -not $coveredKeys.ContainsKey((Get-QueueEntryKey $_))
    } | Sort-Object PairName, RelPath)
    $displayEntries = @($deletes) + @($directoryJobs | ForEach-Object { $_.Root }) + @($files)

    return [pscustomobject]@{
        Deletes = @($deletes)
        DirectoryJobs = @($directoryJobs.ToArray())
        Files = @($files)
        DisplayEntries = @($displayEntries)
        RawCount = $allEntries.Count
    }
}

function Remove-DirectoryTreeSafe {
    param([string]$Path)
    if ([IO.Path]::GetFileName($Path) -notmatch '^\..+\.mqdirtemp-[0-9a-fA-F]{32}$') { throw 'Not an owned directory staging path' }
    Remove-OwnedPath ([IO.Path]::GetDirectoryName($Path)) $Path -Recurse
}

function Get-DirectoryStagingPath {
    param([string]$Destination, [string]$Id = "")
    if ([string]::IsNullOrWhiteSpace($Id)) { $Id = [guid]::NewGuid().ToString("N") }
    $parent = Split-Path -Parent $Destination
    $leaf = Split-Path -Leaf $Destination
    return (Join-Path $parent (".{0}.mqdirtemp-{1}" -f $leaf, $Id))
}



function Build-DirectoryTreeRobocopyArgs {
    param([object]$Pair, [string]$Source, [string]$Destination)
    $copyFlags = "D"
    if ([bool]$script:Config.CopyAttributes) { $copyFlags += "A" }
    if ([bool]$script:Config.PreserveModifiedTime) { $copyFlags += "T" }
    $args = @(
        $Source, $Destination, "/E", "/FFT", "/Z",
        ("/MT:{0}" -f [int]$script:Config.RobocopyThreads),
        ("/R:{0}" -f [int]$script:Config.RobocopyRetries),
        ("/W:{0}" -f [int]$script:Config.RobocopyWaitSeconds),
        ("/COPY:{0}" -f $copyFlags), ("/DCOPY:{0}" -f $copyFlags),
        "/XJ", "/NP", "/NFL", "/NDL", "/NJH", "/NJS"
    )
    $excludeDirs = @()
    $excludeDirs += @(Get-Array $script:Config.GlobalExcludeDirs)
    $excludeDirs += @(Get-MapArray "PairExcludeDirs" $Pair.Name | ForEach-Object {
        Convert-PairExcludeDirForRobocopy $Pair ([string]$_)
    } | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    $excludeFiles = @()
    $excludeFiles += @(Get-Array $script:Config.GlobalExcludeFiles)
    $excludeFiles += @(Get-MapArray "PairExcludeFiles" $Pair.Name | ForEach-Object {
        $pattern=([string]$_).Replace('/','\')
        if ($pattern.Contains('\') -and -not [IO.Path]::IsPathRooted($pattern)) { [IO.Path]::Combine([string]$Pair.Source,$pattern) } else { $pattern }
    })
    if ($excludeDirs.Count -gt 0) { $args += "/XD"; $args += $excludeDirs }
    if ($excludeFiles.Count -gt 0) { $args += "/XF"; $args += $excludeFiles }
    return @($args)
}

function Invoke-StagedDirectoryMerge {
    param([string]$StageRoot, [string]$DestinationRoot)
    try {
        Assert-NoReparsePath $StageRoot
        Assert-NoReparsePath $DestinationRoot
        [System.IO.Directory]::CreateDirectory($DestinationRoot) | Out-Null
        $stageDirectories = @(Get-ChildItem -LiteralPath $StageRoot -Directory -Recurse -Force -ErrorAction Stop |
            Sort-Object @{Expression={ Get-QueuePathDepth (Get-RelativePath $StageRoot $_.FullName) }})
        foreach ($dir in $stageDirectories) {
            $rel = Get-RelativePath $StageRoot $dir.FullName
            $target = Join-PathSafe $DestinationRoot $rel
            Assert-NoReparsePath $target
            [System.IO.Directory]::CreateDirectory($target) | Out-Null
        }
        $stageFiles = @(Get-ChildItem -LiteralPath $StageRoot -File -Recurse -Force -ErrorAction Stop)
        $bytesCopied = [int64]0
        foreach ($file in $stageFiles) {
            $rel = Get-RelativePath $StageRoot $file.FullName
            $target = Join-PathSafe $DestinationRoot $rel
            Assert-NoReparsePath $target
            if (Test-FileNeedsCopy -Source $file.FullName -Dest $target -SourceItem $file) {
                $copy = Copy-FileSafe -Source $file.FullName -Dest $target -SourceItem $file
                $bytesCopied += [int64]$copy.BytesCopied
            }
        }
        $allDirectories = @((Get-Item -LiteralPath $StageRoot -Force)) + $stageDirectories
        foreach ($dir in $allDirectories) {
            $rel = Get-RelativePath $StageRoot $dir.FullName
            $target = if ([string]::IsNullOrWhiteSpace($rel)) { $DestinationRoot } else { Join-PathSafe $DestinationRoot $rel }
            if ([bool]$script:Config.PreserveModifiedTime) {
                try { (Get-Item -LiteralPath $target -Force).LastWriteTimeUtc = $dir.LastWriteTimeUtc } catch {}
            }
            if ([bool]$script:Config.CopyAttributes) {
                try { (Get-Item -LiteralPath $target -Force).Attributes = $dir.Attributes } catch {}
            }
        }
        return [pscustomobject]@{ Status="OK"; Message="Merged staged directory safely"; TreeFiles=$stageFiles.Count; TreeDirs=($stageDirectories.Count + 1); BytesCopied=$bytesCopied }
    } catch {
        return [pscustomobject]@{ Status="FAILED"; Message=(Format-ErrorSummary $_.Exception.Message); TreeFiles=0; TreeDirs=0; BytesCopied=0 }
    }
}

function Invoke-NewDirectoryTreeCopy {
    param([object]$Job, [bool]$DestinationOnline)
    $root = $Job.Root
    $pair = Find-PairByName ([string]$root.PairName)
    if ($null -eq $pair) {
        $result = [pscustomobject]@{ Pair=$root.PairName; Action="COPYTREE"; Path=$root.RelPath; Status="FAILED"; Message="Pair not found" }
        return [pscustomobject]@{ Results=@([pscustomobject]@{Entry=$root;Result=$result}); SuccessfulKeys=@(); AggregateResult=$result }
    }
    if (-not $DestinationOnline) {
        $result = [pscustomobject]@{ Pair=$root.PairName; Action="COPYTREE"; Path=$root.RelPath; Status="SKIPPED"; Message="Destination drive offline"; RetainPending=$true }
        return [pscustomobject]@{ Results=@([pscustomobject]@{Entry=$root;Result=$result}); SuccessfulKeys=@(); AggregateResult=$result }
    }
    $source = Join-PathSafe ([string]$pair.Source) ([string]$root.RelPath)
    $destRoot = Resolve-DestinationPath ([string]$pair.Dest)
    $dest = Join-PathSafe $destRoot ([string]$root.RelPath)
    if (-not (Test-Path -LiteralPath $source -PathType Container)) {
        $result = [pscustomobject]@{ Pair=$root.PairName; Action="COPYTREE"; Path=$root.RelPath; Status="FAILED"; Message="Source missing" }
        return [pscustomobject]@{ Results=@([pscustomobject]@{Entry=$root;Result=$result}); SuccessfulKeys=@(); AggregateResult=$result }
    }
    $stageTree = Get-DirectoryStagingPath -Destination $dest
    $result = $null
    $proc = $null
    try {
        $null = Get-SafeEntryPaths $pair $root
        if (Test-Excluded $pair $source $true) { throw 'Directory excluded by current configuration' }
        $null = @(Get-SafeTreeItems $source $pair)
        [System.IO.Directory]::CreateDirectory($stageTree) | Out-Null
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "robocopy.exe"
        $psi.Arguments = ConvertTo-ProcessArgumentString (Build-DirectoryTreeRobocopyArgs -Pair $pair -Source $source -Destination $stageTree)
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        [void]$proc.Start()
        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
        $stderrTask = $proc.StandardError.ReadToEndAsync()
        $proc.WaitForExit()
        $stdout = $stdoutTask.Result
        $stderr = $stderrTask.Result
        $code = [int]$proc.ExitCode
        $proc.Dispose(); $proc=$null
        if ($code -gt 7) { throw ("Robocopy failed with code {0}: {1} {2}" -f $code, $stderr.Trim(), (($stdout -split "`r?`n" | Select-Object -Last 12) -join " ")) }
        $stageFiles = @(Get-ChildItem -LiteralPath $stageTree -File -Recurse -Force -ErrorAction Stop)
        $stageDirs = @(Get-ChildItem -LiteralPath $stageTree -Directory -Recurse -Force -ErrorAction Stop)
        $treeBytes = [int64](($stageFiles | Measure-Object Length -Sum).Sum)
        $null = Get-SafeEntryPaths $pair $root
        if (Test-Path -LiteralPath $dest) {
            $merge = Invoke-StagedDirectoryMerge -StageRoot $stageTree -DestinationRoot $dest
            $aggregate = [pscustomobject]@{ Pair=$root.PairName; Action="COPYTREE"; Path=$root.RelPath; Status=$merge.Status; Message=$merge.Message; TreeFiles=$merge.TreeFiles; TreeDirs=$merge.TreeDirs; BytesCopied=$merge.BytesCopied }
            $successful = if ($merge.Status -eq "OK") { @($Job.Entries | ForEach-Object { Get-QueueEntryKey $_ }) } else { @() }
            return [pscustomobject]@{ Results=@([pscustomobject]@{Entry=$root;Result=$aggregate}); SuccessfulKeys=$successful; AggregateResult=$aggregate }
        }
        $destParent = Split-Path -Parent $dest
        [System.IO.Directory]::CreateDirectory($destParent) | Out-Null
        [System.IO.Directory]::Move($stageTree, $dest)
        $successful = @($Job.Entries | ForEach-Object { Get-QueueEntryKey $_ })
        $result = [pscustomobject]@{ Pair=$root.PairName; Action="COPYTREE"; Path=$root.RelPath; Status="OK"; Message=("Copied as one directory job ({0} queued items)" -f @($Job.Entries).Count); TreeFiles=$stageFiles.Count; TreeDirs=($stageDirs.Count + 1); BytesCopied=$treeBytes }
        return [pscustomobject]@{ Results=@([pscustomobject]@{Entry=$root;Result=$result}); SuccessfulKeys=$successful; AggregateResult=$result }
    } catch {
        $result = [pscustomobject]@{ Pair=$root.PairName; Action="COPYTREE"; Path=$root.RelPath; Status="FAILED"; Message=(Format-ErrorSummary $_.Exception.Message) }
        Write-Log "ERROR" ("Directory tree copy failed: {0} :: {1}" -f $root.RelPath, $_.Exception.Message)
        return [pscustomobject]@{ Results=@([pscustomobject]@{Entry=$root;Result=$result}); SuccessfulKeys=@(); AggregateResult=$result }
    } finally {
        if ($null -ne $proc) { try { if (-not $proc.HasExited) { $proc.Kill(); $proc.WaitForExit() } } finally { $proc.Dispose() } }
        try {
            if ([System.IO.Directory]::Exists($stageTree)) { Remove-DirectoryTreeSafe -Path $stageTree }
        } catch {}
    }
}

function Invoke-ParallelFileTransfers {
    param(
        [object[]]$Entries,
        [hashtable]$PairOnline,
        [object]$ProgressTable,
        [hashtable]$EntryIndexes,
        [object]$PairOverride = $null,
        [switch]$MissingOnly
    )
    $completed = New-Object System.Collections.Generic.List[object]
    $pendingGroups = @{}
    $readyGroupKeys = New-Object System.Collections.Queue
    foreach ($entry in @($Entries)) {
        $pair = if ($null -ne $PairOverride) { $PairOverride } else { Find-PairByName ([string]$entry.PairName) }
        $key = Get-QueueEntryKey $entry
        $rowIndex = if ($EntryIndexes.ContainsKey($key)) { [int]$EntryIndexes[$key] } else { -1 }
        if ($null -eq $pair) {
            $result = [pscustomobject]@{ Pair=$entry.PairName; Action="COPY"; Path=$entry.RelPath; Status="FAILED"; Message="Pair not found" }
            $completed.Add([pscustomobject]@{ Entry=$entry; Result=$result }) | Out-Null
            Update-ApplyProgressRow -Table $ProgressTable -Index $rowIndex -Status "FAILED" -Complete -ForceRender
            continue
        }
        $pairKey = ([string]$entry.PairName).ToUpperInvariant()
        $online = ($PairOnline.ContainsKey($pairKey) -and [bool]$PairOnline[$pairKey])
        if (-not $online) {
            $result = Apply-OneEntry -Entry $entry -DestinationOnline $false
            $completed.Add([pscustomobject]@{ Entry=$entry; Result=$result }) | Out-Null
            Update-ApplyProgressRow -Table $ProgressTable -Index $rowIndex -Status (Get-ApplyProgressFinalStatus $result) -Complete -ForceRender
            continue
        }
        try {
            $paths = Get-SafeEntryPaths $pair $entry
            if (Test-Excluded $pair $paths.Source $false) { throw 'Excluded by current configuration' }
            $destination = $paths.Destination
            $destinationKey = Get-PhysicalDestinationKey $destination
            if (-not $pendingGroups.ContainsKey($destinationKey)) {
                $pendingGroups[$destinationKey] = New-Object System.Collections.Queue
                $readyGroupKeys.Enqueue($destinationKey)
            }
            $pendingGroups[$destinationKey].Enqueue($entry)
        } catch {
            $result = [pscustomobject]@{ Pair=$entry.PairName; Action="COPY"; Path=$entry.RelPath; Status="FAILED"; Message=(Format-ErrorSummary $_.Exception.Message) }
            $completed.Add([pscustomobject]@{ Entry=$entry; Result=$result }) | Out-Null
            Update-ApplyProgressRow -Table $ProgressTable -Index $rowIndex -Status "FAILED" -Complete -ForceRender
        }
    }
    if ($readyGroupKeys.Count -eq 0) { return @($completed.ToArray()) }

    $maxParallel = [math]::Max(1, [math]::Min(32, [int]$script:Config.ParallelFileTransfers))
    $script:LastParallelFileTransferLimit = $maxParallel
    $script:LastParallelFileTransferPeakHandles = 0
    $progressState = [hashtable]::Synchronized(@{})
    $workerScript = {
        param($JobId, $Entry, $Source, $Destination, $CopyTempThenReplace, $PreserveModifiedTime, $CopyAttributes, $TimeToleranceSeconds, $SharedProgress, $MissingOnly)
        $sourceItem = $null
        $tmp = $null
        $backup = $null
        try {
            if (-not [System.IO.File]::Exists($Source)) {
                return [pscustomobject]@{ Pair=$Entry.PairName; Action="COPY"; Path=$Entry.RelPath; Status="FAILED"; Message="Source missing" }
            }
            # Attribute reads distinguish permission errors from absence; File.Exists does not.
            $attributes = $null
            try { $attributes=[IO.File]::GetAttributes($Destination) }
            catch [IO.FileNotFoundException] { }
            catch [IO.DirectoryNotFoundException] { }
            if ($null -ne $attributes -and ($attributes -band [IO.FileAttributes]::ReparsePoint -or $attributes -band [IO.FileAttributes]::Directory)) { throw 'Unsafe destination kind' }
            if ($MissingOnly -and $null -ne $attributes) { return [pscustomobject]@{Pair=$Entry.PairName;Action='COPY';Path=$Entry.RelPath;Status='SKIPPED';Message='Existing destination preserved'} }
            $sourceItem = [System.IO.FileInfo]::new($Source)
            if ([System.IO.File]::Exists($Destination)) {
                $destItem = [System.IO.FileInfo]::new($Destination)
                $timeDiff = [math]::Abs(($sourceItem.LastWriteTimeUtc - $destItem.LastWriteTimeUtc).TotalSeconds)
                if ($sourceItem.Length -eq $destItem.Length -and $timeDiff -le [double]$TimeToleranceSeconds) {
                    return [pscustomobject]@{ Pair=$Entry.PairName; Action="COPY"; Path=$Entry.RelPath; Status="SKIPPED"; Message="Already current"; BytesCopied=[int64]$sourceItem.Length; TotalBytes=[int64]$sourceItem.Length }
                }
            }
            $destDir = [System.IO.Path]::GetDirectoryName($Destination)
            [System.IO.Directory]::CreateDirectory($destDir) | Out-Null
            $target = $Destination
            if ([bool]$CopyTempThenReplace) {
                $tmp = [System.IO.Path]::Combine($destDir, (".{0}.mqtmp-{1}" -f [System.IO.Path]::GetFileName($Destination), [guid]::NewGuid().ToString("N")))
                $target = $tmp
            }
            $total = [int64]$sourceItem.Length
            $copied = [int64]0
            $started = [datetime]::UtcNow
            $SharedProgress[$JobId] = @{ Status="COPYING"; Copied=$copied; Total=$total; StartedAt=$started }
            $inputStream = $null
            $outputStream = $null
            try {
                $inputStream = New-Object System.IO.FileStream($Source, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read, 1048576, [System.IO.FileOptions]::SequentialScan)
                $outputStream = New-Object System.IO.FileStream($target, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None, 1048576, [System.IO.FileOptions]::SequentialScan)
                $buffer = New-Object byte[] 1048576
                while (($read = $inputStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    $outputStream.Write($buffer, 0, $read)
                    $copied += [int64]$read
                    $SharedProgress[$JobId] = @{ Status="COPYING"; Copied=$copied; Total=$total; StartedAt=$started }
                }
                $outputStream.Flush()
            } finally {
                if ($null -ne $outputStream) { $outputStream.Dispose() }
                if ($null -ne $inputStream) { $inputStream.Dispose() }
            }
            if ([bool]$PreserveModifiedTime) { [System.IO.File]::SetLastWriteTimeUtc($target, $sourceItem.LastWriteTimeUtc) }
            if ([bool]$CopyAttributes) { [System.IO.File]::SetAttributes($target, $sourceItem.Attributes) }
            if ([bool]$CopyTempThenReplace) {
                if ($MissingOnly) {
                    # Move without overwrite closes the missing-only race.
                    [IO.File]::Move($tmp,$Destination); $tmp=$null
                } elseif ([System.IO.File]::Exists($Destination)) {
                    $attrs = [System.IO.File]::GetAttributes($Destination)
                    if (($attrs -band [System.IO.FileAttributes]::ReadOnly) -ne 0) {
                        [System.IO.File]::SetAttributes($Destination, ($attrs -band (-bnot [System.IO.FileAttributes]::ReadOnly)))
                    }
                    $backup = [System.IO.Path]::Combine($destDir, (".{0}.mqbackup-{1}" -f [System.IO.Path]::GetFileName($Destination), [guid]::NewGuid().ToString("N")))
                    [System.IO.File]::Replace($tmp, $Destination, $backup)
                    try { if ([System.IO.File]::Exists($backup)) { [System.IO.File]::Delete($backup) } } catch {}
                    if (-not [System.IO.File]::Exists($backup)) { $backup = $null }
                    $tmp = $null
                } else {
                    [System.IO.File]::Move($tmp, $Destination)
                    $tmp = $null
                }
            }
            return [pscustomobject]@{ Pair=$Entry.PairName; Action="COPY"; Path=$Entry.RelPath; Status="OK"; Message=""; BytesCopied=$copied; TotalBytes=$total }
        } catch {
            return [pscustomobject]@{ Pair=$Entry.PairName; Action="COPY"; Path=$Entry.RelPath; Status="FAILED"; Message=$_.Exception.Message }
        } finally {
            if (-not [string]::IsNullOrWhiteSpace($tmp) -and [System.IO.File]::Exists($tmp)) {
                try { [System.IO.File]::SetAttributes($tmp, [System.IO.FileAttributes]::Normal); [System.IO.File]::Delete($tmp) } catch {}
            }
            if (-not [string]::IsNullOrWhiteSpace($backup) -and [System.IO.File]::Exists($backup)) {
                try { [System.IO.File]::SetAttributes($backup, [System.IO.FileAttributes]::Normal); [System.IO.File]::Delete($backup) } catch {}
            }
        }
    }

    $pool = [runspacefactory]::CreateRunspacePool(1, $maxParallel)
    $jobs = New-Object System.Collections.Generic.List[object]
    try {
        $pool.Open()
        while ($readyGroupKeys.Count -gt 0 -or $jobs.Count -gt 0) {
            while ($jobs.Count -lt $maxParallel -and $readyGroupKeys.Count -gt 0) {
                $groupKey = [string]$readyGroupKeys.Dequeue()
                $entry = $pendingGroups[$groupKey].Dequeue()
                $pair = if ($null -ne $PairOverride) { $PairOverride } else { Find-PairByName ([string]$entry.PairName) }
                $entryKey = Get-QueueEntryKey $entry
                $rowIndex = if ($EntryIndexes.ContainsKey($entryKey)) { [int]$EntryIndexes[$entryKey] } else { -1 }
                $item = [pscustomobject]@{
                    Id = [guid]::NewGuid().ToString("N")
                    Entry = $entry
                    Source = Join-PathSafe ([string]$pair.Source) ([string]$entry.RelPath)
                    Destination = Join-PathSafe (Resolve-DestinationPath ([string]$pair.Dest)) ([string]$entry.RelPath)
                    RowIndex = $rowIndex
                    GroupKey = $groupKey
                }
                $ps = [powershell]::Create()
                $ps.RunspacePool = $pool
                [void]$ps.AddScript($workerScript.ToString())
                [void]$ps.AddArgument($item.Id)
                [void]$ps.AddArgument($item.Entry)
                [void]$ps.AddArgument($item.Source)
                [void]$ps.AddArgument($item.Destination)
                [void]$ps.AddArgument([bool]($script:Config.CopyTempThenReplace -or $MissingOnly))
                [void]$ps.AddArgument([bool]$script:Config.PreserveModifiedTime)
                [void]$ps.AddArgument([bool]$script:Config.CopyAttributes)
                [void]$ps.AddArgument([double]$script:Config.TimeToleranceSeconds)
                [void]$ps.AddArgument($progressState)
                [void]$ps.AddArgument([bool]$MissingOnly)
                try {
                    $handle = $ps.BeginInvoke()
                    $jobs.Add([pscustomobject]@{ Item=$item; PowerShell=$ps; Handle=$handle }) | Out-Null
                    if ($jobs.Count -gt $script:LastParallelFileTransferPeakHandles) {
                        $script:LastParallelFileTransferPeakHandles = $jobs.Count
                    }
                } catch {
                    $ps.Dispose()
                    $result = [pscustomobject]@{ Pair=$item.Entry.PairName; Action="COPY"; Path=$item.Entry.RelPath; Status="FAILED"; Message=(Format-ErrorSummary $_.Exception.Message) }
                    $completed.Add([pscustomobject]@{ Entry=$item.Entry; Result=$result }) | Out-Null
                    Update-ApplyProgressRow -Table $ProgressTable -Index $item.RowIndex -Status "FAILED" -Complete -ForceRender
                    if ($pendingGroups[$groupKey].Count -gt 0) { $readyGroupKeys.Enqueue($groupKey) }
                }
            }

            foreach ($job in @($jobs.ToArray())) {
                $state = if ($progressState.ContainsKey($job.Item.Id)) { $progressState[$job.Item.Id] } else { $null }
                if ($null -ne $state) {
                    Update-ApplyProgressRow -Table $ProgressTable -Index $job.Item.RowIndex -Status ([string]$state.Status) -CopiedBytes ([int64]$state.Copied) -TotalBytes ([int64]$state.Total) -StartedAt ([datetime]$state.StartedAt)
                }
                if (-not $job.Handle.IsCompleted) { continue }
                try {
                    $output = @($job.PowerShell.EndInvoke($job.Handle))
                    $result = if ($output.Count -gt 0) { $output[-1] } else { $null }
                    if ($null -eq $result) { throw "Parallel copy worker returned no result" }
                    if ($result.Status -eq "FAILED") { Write-Log "ERROR" ("File transfer failed: " + $job.Item.Entry.RelPath + " :: " + $result.Message); $result.Message = Format-ErrorSummary ([string]$result.Message) }
                } catch {
                    $result = [pscustomobject]@{ Pair=$job.Item.Entry.PairName; Action="COPY"; Path=$job.Item.Entry.RelPath; Status="FAILED"; Message=(Format-ErrorSummary $_.Exception.Message) }
                } finally {
                    $job.PowerShell.Dispose()
                }
                $completed.Add([pscustomobject]@{ Entry=$job.Item.Entry; Result=$result }) | Out-Null
                $finalStatus = Get-ApplyProgressFinalStatus $result
                $finalTotal = if ($null -ne $result.PSObject.Properties["TotalBytes"]) { [int64]$result.TotalBytes } else { Get-ApplyEntryTotalBytes $job.Item.Entry }
                $finalCopied = if ($null -ne $result.PSObject.Properties["BytesCopied"]) { [int64]$result.BytesCopied } else { [int64]0 }
                Update-ApplyProgressRow -Table $ProgressTable -Index $job.Item.RowIndex -Status $finalStatus -CopiedBytes $finalCopied -TotalBytes $finalTotal -Complete -ForceRender
                [void]$jobs.Remove($job)
                $progressState.Remove($job.Item.Id)
                if ($pendingGroups[$job.Item.GroupKey].Count -gt 0) { $readyGroupKeys.Enqueue($job.Item.GroupKey) }
            }
            if ($jobs.Count -gt 0) { Start-Sleep -Milliseconds 100 }
        }
    } finally {
        foreach ($job in @($jobs.ToArray())) {
            try { $job.PowerShell.Stop() } catch {}
            try { $job.PowerShell.Dispose() } catch {}
        }
        try { $pool.Close() } catch {}
        try { $pool.Dispose() } catch {}
    }
    return @($completed.ToArray())
}

function Invoke-ApplyPending {
    param([switch]$Quiet, [object]$Snapshot = $null)
    if (-not (Enter-ApplyLock -Operation "Apply Pending" -Quiet:$Quiet)) { return }
    try {
        $Snapshot = Sync-PendingSessionSnapshot -RefreshDestinations -ShowProgress:(-not $Quiet)
        $latest = @($Snapshot.Entries)
        if ($latest.Count -eq 0) {
            if (-not $Quiet) {
                Show-Header "Apply Pending" "No queued changes"
                Write-Color "Queue is empty." "Green"
                Wait-Back
            }
            return
        }
        Show-Header "Apply Pending" "Recorded source changes only"
        $plan = Get-ApplyExecutionPlan $latest
        if ($plan.RawCount -ne @($plan.DisplayEntries).Count) {
            Write-Color ("  {0} queued changes grouped into {1} transfer jobs" -f $plan.RawCount, @($plan.DisplayEntries).Count) "DarkGray"
        }
        $results = New-Object System.Collections.Generic.List[object]
        $okKeys = New-Object System.Collections.Generic.List[string]
        $pairOnline = $Snapshot.PairOnline
        $entryIndexes = @{}
        for ($i = 0; $i -lt @($plan.DisplayEntries).Count; $i++) {
            $entryIndexes[(Get-QueueEntryKey $plan.DisplayEntries[$i])] = $i
        }
        $cursorChanged = $false
        $previousCursorVisible = $true
        try {
            try {
                if (-not [Console]::IsOutputRedirected) {
                    $previousCursorVisible = [Console]::CursorVisible
                    [Console]::CursorVisible = $false
                    $cursorChanged = $true
                }
            } catch {}

            $progressTable = New-ApplyProgressTable -Entries @($plan.DisplayEntries)
            foreach ($entry in @($plan.Deletes)) {
                $key = Get-QueueEntryKey $entry
                $rowIndex = [int]$entryIndexes[$key]
                $startedAt = Get-Date
                Update-ApplyProgressRow -Table $progressTable -Index $rowIndex -Status (Get-ApplyProgressStartingStatus $entry) -StartedAt $startedAt -ForceRender
                $pairKey = ([string]$entry.PairName).ToUpperInvariant()
                $online = ($pairOnline.ContainsKey($pairKey) -and [bool]$pairOnline[$pairKey])
                $result = Apply-OneEntry -Entry $entry -DestinationOnline $online
                Update-ApplyProgressRow -Table $progressTable -Index $rowIndex -Status (Get-ApplyProgressFinalStatus $result) -Complete -ForceRender
                $results.Add($result) | Out-Null
                $retain = ($null -ne $result.PSObject.Properties["RetainPending"] -and [bool]$result.RetainPending)
                if ($result.Status -ne "FAILED" -and $result.Message -ne "Destination drive offline" -and -not $retain) {
                    $okKeys.Add($key) | Out-Null
                }
            }

            foreach ($directoryJob in @($plan.DirectoryJobs)) {
                $root = $directoryJob.Root
                $rowIndex = [int]$entryIndexes[(Get-QueueEntryKey $root)]
                $startedAt = Get-Date
                Update-ApplyProgressRow -Table $progressTable -Index $rowIndex -Status "COPYING" -StartedAt $startedAt -ForceRender
                $pairKey = ([string]$root.PairName).ToUpperInvariant()
                $online = ($pairOnline.ContainsKey($pairKey) -and [bool]$pairOnline[$pairKey])
                $outcome = Invoke-NewDirectoryTreeCopy -Job $directoryJob -DestinationOnline $online
                $finalStatus = Get-ApplyProgressFinalStatus $outcome.AggregateResult
                $treeTotalBytes = Get-ApplyEntryTotalBytes $root
                $treeCopiedBytes = if ($finalStatus -eq "DONE") {
                    $treeTotalBytes
                } elseif ($null -ne $outcome.AggregateResult.PSObject.Properties["BytesCopied"]) {
                    [int64]$outcome.AggregateResult.BytesCopied
                } else {
                    [int64]0
                }
                Update-ApplyProgressRow -Table $progressTable -Index $rowIndex -Status $finalStatus -CopiedBytes $treeCopiedBytes -TotalBytes $treeTotalBytes -Complete -ForceRender
                foreach ($record in @($outcome.Results)) {
                    $results.Add($record.Result) | Out-Null
                }
                foreach ($successKey in @($outcome.SuccessfulKeys)) { $okKeys.Add([string]$successKey) | Out-Null }
            }

            $fileRecords = @(Invoke-ParallelFileTransfers -Entries @($plan.Files) -PairOnline $pairOnline -ProgressTable $progressTable -EntryIndexes $entryIndexes)
            foreach ($record in $fileRecords) {
                $entry = $record.Entry
                $result = $record.Result
                $results.Add($result) | Out-Null
                $retain = ($null -ne $result.PSObject.Properties["RetainPending"] -and [bool]$result.RetainPending)
                if ($result.Status -ne "FAILED" -and $result.Message -ne "Destination drive offline" -and -not $retain) {
                    $okKeys.Add((Get-QueueEntryKey $entry)) | Out-Null
                }
            }
            Remove-AppliedQueueEntries -AttemptedEntries $latest -SuccessfulKeys @($okKeys.ToArray()) | Out-Null
        } finally {
            if ($cursorChanged) {
                try { [Console]::CursorVisible = $previousCursorVisible } catch {}
            }
        }
        Show-ApplyResults -Results @($results.ToArray()) -Title "Apply Results" -Compact
        $script:PendingSessionSnapshot = $null
    } finally {
        $script:PendingSessionSnapshot = $null
        Exit-ApplyLock
    }
}

function Show-PendingPreview {
    param([object]$Snapshot = $null)
    if ($null -eq $Snapshot) { $Snapshot = Sync-PendingSessionSnapshot -RefreshDestinations -ShowProgress -ReadOnly }
    $latest = @($Snapshot.Entries)
    if ($latest.Count -eq 0) {
        Show-Header "Preview Pending" "Local pending decisions"
        Write-Color "No pending changes found." "Green"
        Wait-Back
        return
    }
    $plan = Get-ApplyExecutionPlan $latest
    $previewItems = @($plan.DisplayEntries)
    $pageSize = 100
    $pageCount = [math]::Max(1, [math]::Ceiling($previewItems.Count / [double]$pageSize))
    $page = 0
    while ($true) {
        Show-Header "Preview Pending" "Read-only preview - apply rechecks current paths"
        Write-Color ("Changes: {0}    Transfer jobs: {1}    Add: {2}    Update: {3}    Delete: {4}" -f $latest.Count, $previewItems.Count, @($latest | Where-Object Operation -eq "Add").Count, @($latest | Where-Object Operation -eq "Update").Count, @($latest | Where-Object Operation -eq "Delete").Count) "Cyan"
        $pairSummary = @($latest | Group-Object PairName | Sort-Object Count -Descending)
        Write-Color ("By pair: " + (@($pairSummary | Select-Object -First 8 | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join "  ")) "DarkGray"
        Write-Host ""
        $start = $page * $pageSize
        $end = [math]::Min($previewItems.Count - 1, $start + $pageSize - 1)
        Write-PendingTable -Items @($previewItems[$start..$end]) -StartIndex $start -TotalCount $previewItems.Count
        Write-Host ""
        Write-Color ("Page {0}/{1}    N = next    P = previous    Enter = apply    Esc = back" -f ($page + 1), $pageCount) "DarkGray"
        if ($script:SuppressPause) { return }
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq [ConsoleKey]::Escape) { return }
        if ($key.Key -eq [ConsoleKey]::Enter) { Invoke-ApplyPending -Snapshot $Snapshot; return }
        if ($key.Key -eq [ConsoleKey]::N -and $page -lt ($pageCount - 1)) { $page++; continue }
        if ($key.Key -eq [ConsoleKey]::P -and $page -gt 0) { $page--; continue }
    }
}

function Get-DisplayAction {
    param([object]$Entry)
    if ($Entry.Action -eq "Delete" -or [string]$Entry.Operation -eq "Delete") { return "DELETE" }
    if ([string]$Entry.Operation -eq "Add" -or [string]$Entry.BaselineState -eq "Absent") { return "ADD" }
    return "UPDATE"
}

function Test-ApplyResultVisible {
    param([object]$Result)
    if ($null -eq $Result) { return $false }
    if ($Result.Status -eq "FAILED") { return $true }
    if ($Result.Action -eq "MKDIR" -and $Result.Status -eq "SKIPPED" -and $Result.Message -eq "Directory exists") { return $false }
    if ($Result.Action -eq "DELETE" -and $Result.Status -eq "SKIPPED" -and $Result.Message -eq "Destination missing") { return $false }
    return $true
}

function Write-PendingTable {
    param([object[]]$Items, [int]$StartIndex = 0, [int]$TotalCount = 0)
    if ($TotalCount -le 0) { $TotalCount = @($Items).Count }
    $wNo = 11; $wPair = 22; $wAction = 8; $wKind = 6; $wPath = 48
    $line = "+" + ("-"*($wNo+2)) + "+" + ("-"*($wPair+2)) + "+" + ("-"*($wAction+2)) + "+" + ("-"*($wKind+2)) + "+" + ("-"*($wPath+2)) + "+"
    Write-Color $line "DarkGray"
    Write-Color ("| {0} | {1} | {2} | {3} | {4} |" -f (Center-Text "No." $wNo),(Center-Text "Pair" $wPair),(Center-Text "Action" $wAction),(Center-Text "Kind" $wKind),(Center-Text "Path" $wPath)) "DarkGray"
    Write-Color $line "DarkGray"
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $e = $Items[$i]
        $coveredCount = if ($null -ne $e.PSObject.Properties["CoveredCount"]) { [int]$e.CoveredCount } else { 0 }
        $kind = if ($coveredCount -gt 1) { "TREE" } elseif ($e.IsDirectory) { "DIR" } else { "FILE" }
        $action = Get-DisplayAction $e
        $color = if ($action -eq "DELETE") { "Red" } elseif ($action -eq "ADD") { "Green" } else { "Yellow" }
        Write-Color "| " "DarkGray" -NoNewLine
        Write-Color (Center-Text ("{0}/{1}" -f ($StartIndex + $i + 1), $TotalCount) $wNo) "DarkGray" -NoNewLine
        Write-Color " | " "DarkGray" -NoNewLine
        Write-Color (Fit-Cell $e.PairName $wPair) "Cyan" -NoNewLine
        Write-Color " | " "DarkGray" -NoNewLine
        Write-Color (Center-Text $action $wAction) $color -NoNewLine
        Write-Color " | " "DarkGray" -NoNewLine
        Write-Color (Center-Text $kind $wKind) "White" -NoNewLine
        Write-Color " | " "DarkGray" -NoNewLine
        $pathText = if ($coveredCount -gt 1) { "{0} [{1} items]" -f [string]$e.RelPath, $coveredCount } else { [string]$e.RelPath }
        Write-Color (Fit-Cell $pathText $wPath) "White" -NoNewLine
        Write-Color " |" "DarkGray"
    }
    Write-Color $line "DarkGray"
}

function Show-ApplyResults {
    param([object[]]$Results, [string]$Title, [switch]$Compact)
    Show-Header $Title "Press any key after review"
    $visibleResults = @($Results | Where-Object { Test-ApplyResultVisible $_ })
    if ($visibleResults.Count -eq 0 -and -not $Compact) {
        Write-Color "No destination changes were needed." "Green"
        Wait-Back
        return
    }
    if (-not $Compact) {
        $wPair = 22; $wAction = 8; $wStatus = 8; $wPath = 42; $wMsg = 24
        $line = "+" + ("-"*($wPair+2)) + "+" + ("-"*($wAction+2)) + "+" + ("-"*($wStatus+2)) + "+" + ("-"*($wPath+2)) + "+" + ("-"*($wMsg+2)) + "+"
        Write-Color $line "DarkGray"
        Write-Color ("| {0} | {1} | {2} | {3} | {4} |" -f (Center-Text "Pair" $wPair),(Center-Text "Action" $wAction),(Center-Text "Status" $wStatus),(Center-Text "Path" $wPath),(Center-Text "Message" $wMsg)) "DarkGray"
        Write-Color $line "DarkGray"
        foreach ($r in $visibleResults) {
            $statusColor = if ($r.Status -eq "OK") { "Green" } elseif ($r.Status -eq "FAILED") { "Red" } else { "Yellow" }
            Write-Color "| " "DarkGray" -NoNewLine
            Write-Color (Fit-Cell $r.Pair $wPair) "Cyan" -NoNewLine
            Write-Color " | " "DarkGray" -NoNewLine
            Write-Color (Center-Text $r.Action $wAction) "Yellow" -NoNewLine
            Write-Color " | " "DarkGray" -NoNewLine
            Write-Color (Center-Text $r.Status $wStatus) $statusColor -NoNewLine
            Write-Color " | " "DarkGray" -NoNewLine
            Write-Color (Fit-Cell $r.Path $wPath) "White" -NoNewLine
            Write-Color " | " "DarkGray" -NoNewLine
            Write-Color (Fit-Cell $r.Message $wMsg) "DarkGray" -NoNewLine
            Write-Color " |" "DarkGray"
        }
        Write-Color $line "DarkGray"
        Wait-Back
        return
    }

    $copied = @($Results | Where-Object { $_.Action -eq "COPY" -and $_.Status -eq "OK" }).Count
    $copied += [int](($Results | Where-Object { $_.Action -eq "COPYTREE" -and $_.Status -eq "OK" -and $null -ne $_.PSObject.Properties["TreeFiles"] } | Measure-Object TreeFiles -Sum).Sum)
    $folders = @($Results | Where-Object { $_.Action -eq "MKDIR" -and $_.Status -eq "OK" }).Count
    $folders += [int](($Results | Where-Object { $_.Action -eq "COPYTREE" -and $_.Status -eq "OK" -and $null -ne $_.PSObject.Properties["TreeDirs"] } | Measure-Object TreeDirs -Sum).Sum)
    $deleted = @($Results | Where-Object { $_.Action -eq "DELETE" -and $_.Status -eq "OK" }).Count
    $skipped = @($Results | Where-Object { $_.Status -eq "SKIPPED" }).Count
    $obsoleteDeletes = @($Results | Where-Object { $_.Action -eq "DELETE" -and $_.Status -eq "SKIPPED" -and $_.Message -eq "Destination missing" }).Count
    $canceledDeletes = @($Results | Where-Object { $_.Action -eq "DELETE" -and $_.Status -eq "SKIPPED" -and $null -ne $_.PSObject.Properties["ResultKind"] -and [string]$_.ResultKind -eq "DeleteCanceled" }).Count
    $failed = @($Results | Where-Object { $_.Status -eq "FAILED" }).Count
    $total = @($Results).Count

    Write-Color ("Displayed items : " + $total) "DarkGray"
    Write-Color ("Copied          : " + $copied) "Green"
    Write-Color ("Folders created : " + $folders) "Green"
    Write-Color ("Deleted         : " + $deleted) "Yellow"
    Write-Color ("Skipped         : " + $skipped) $(if ($skipped -gt 0) { "Yellow" } else { "DarkGray" })
    Write-Color ("Obsolete deletes: " + $obsoleteDeletes) "DarkGray"
    Write-Color ("Deletes canceled: " + $canceledDeletes) $(if ($canceledDeletes -gt 0) { "Cyan" } else { "DarkGray" })
    Write-Color ("Failed          : " + $failed) $(if ($failed -gt 0) { "Red" } else { "DarkGray" })
    Write-Host ""

    $detailResults = @($Results | Where-Object {
        if ($_.Status -eq "FAILED") { return $true }
        if ($_.Status -eq "SKIPPED" -and $_.Message -ne "Already current" -and $_.Message -ne "Directory exists" -and $_.Message -ne "Destination missing" -and -not ($null -ne $_.PSObject.Properties["ResultKind"] -and [string]$_.ResultKind -eq "DeleteCanceled")) { return $true }
        return $false
    })
    if ($detailResults.Count -eq 0) {
        if ($canceledDeletes -gt 0) {
            Write-Color "Pending deletions were retained for reclassification." "Cyan"
        } elseif ($failed -eq 0) {
            Write-Color "All pending changes applied successfully." "Green"
        }
        Wait-Back
        return
    }

    Write-Color "Items needing attention:" "Yellow"
    $wPair = 22; $wAction = 8; $wStatus = 8; $wPath = 42; $wMsg = 24
    $line = "+" + ("-"*($wPair+2)) + "+" + ("-"*($wAction+2)) + "+" + ("-"*($wStatus+2)) + "+" + ("-"*($wPath+2)) + "+" + ("-"*($wMsg+2)) + "+"
    Write-Color $line "DarkGray"
    Write-Color ("| {0} | {1} | {2} | {3} | {4} |" -f (Center-Text "Pair" $wPair),(Center-Text "Action" $wAction),(Center-Text "Status" $wStatus),(Center-Text "Path" $wPath),(Center-Text "Message" $wMsg)) "DarkGray"
    Write-Color $line "DarkGray"
    foreach ($r in $detailResults) {
        $statusColor = if ($r.Status -eq "OK") { "Green" } elseif ($r.Status -eq "FAILED") { "Red" } else { "Yellow" }
        Write-Color "| " "DarkGray" -NoNewLine
        Write-Color (Fit-Cell $r.Pair $wPair) "Cyan" -NoNewLine
        Write-Color " | " "DarkGray" -NoNewLine
        Write-Color (Center-Text $r.Action $wAction) "Yellow" -NoNewLine
        Write-Color " | " "DarkGray" -NoNewLine
        Write-Color (Center-Text $r.Status $wStatus) $statusColor -NoNewLine
        Write-Color " | " "DarkGray" -NoNewLine
        Write-Color (Fit-Cell $r.Path $wPath) "White" -NoNewLine
        Write-Color " | " "DarkGray" -NoNewLine
        Write-Color (Fit-Cell $r.Message $wMsg) "DarkGray" -NoNewLine
        Write-Color " |" "DarkGray"
    }
    Write-Color $line "DarkGray"
    Wait-Back
}

















function New-InternalMirrorScanResult {
    param([object[]]$FileChanges)
    $changes = @($FileChanges)
    $newFiles = @($changes | Where-Object { $_.Action -eq "COPY" -and $_.Type -eq "FILE" -and $_.ChangeAction -eq "NEW" }).Count
    $updatedFiles = @($changes | Where-Object { $_.Action -eq "COPY" -and $_.Type -eq "FILE" -and $_.ChangeAction -eq "UPDATE" }).Count
    $extraFiles = @($changes | Where-Object { $_.Action -eq "DELETE" -and $_.Type -eq "FILE" }).Count
    $newDirs = @($changes | Where-Object { $_.Action -eq "MKDIR" -and $_.Type -eq "DIR" }).Count
    $extraDirs = @($changes | Where-Object { $_.Action -eq "DELETE" -and $_.Type -eq "DIR" }).Count
    $detail = @($changes | ForEach-Object {
        $prefix = switch ($_.ChangeAction) {
            "NEW" { if ($_.Type -eq "DIR") { "New folder: " } else { "New file: " } }
            "UPDATE" { "Update file: " }
            "DELETE" { if ($_.Type -eq "DIR") { "Extra folder: " } else { "Extra file: " } }
            "CLEANUP" { "Cleanup temp file: " }
            default { "Change: " }
        }
        $text = $prefix + [string]$_.RelPath
        if ($text.Length -gt 92) { $text = $text.Substring(0, 92) + "..." }
        $text
    })
    return [pscustomobject]@{
        FileChanges = $changes
        Changes = $detail
        HasChanges = ($changes.Count -gt 0)
        ChangeSummary = [pscustomobject]@{
            NewFiles = $newFiles
            UpdatedFiles = $updatedFiles
            ExtraFiles = $extraFiles
            NewDirs = $newDirs
            ExtraDirs = $extraDirs
        }
        Summary = [pscustomobject]@{
            DirsTotal = 0; DirsCopied = $newDirs; DirsSkipped = 0; DirsMismatch = 0; DirsFailed = 0; DirsExtras = $extraDirs
            FilesTotal = 0; FilesCopied = ($newFiles + $updatedFiles); FilesSkipped = 0; FilesMismatch = 0; FilesFailed = 0; FilesExtras = $extraFiles
        }
    }
}

function Get-InternalMirrorScan {
    param([object]$Pair, [ValidateSet('STRICT','UPDATE_KEEP_EXTRAS','MISSING_ONLY')][string]$Policy, [scriptblock]$ProgressCallback = $null)
    Assert-PairLayout $Pair
    $srcRoot=[IO.Path]::GetFullPath($Pair.Source)
    $dstRoot=[IO.Path]::GetFullPath((Resolve-DestinationPath $Pair.Dest))
    $sourceProbe=Get-ExactPathProbe $srcRoot
    if ($sourceProbe.State -ne 'Exists' -or -not $sourceProbe.IsDirectory) { throw 'Source root unavailable' }
    $destProbe=Get-ExactPathProbe $dstRoot
    if ($destProbe.State -eq 'Error' -or ($destProbe.State -eq 'Exists' -and -not $destProbe.IsDirectory) -or -not (Test-DestRootAvailable $dstRoot)) { throw 'Destination root unavailable or invalid' }
    $sourceItems=@(Get-SafeTreeItems $srcRoot $Pair)
    $destItems=if ($destProbe.State -eq 'Exists') { @(Get-SafeTreeItems $dstRoot $Pair -EquivalentRoot $srcRoot) } else { @() }
    $sources=@{}; $destinations=@{}; $changes=[Collections.Generic.List[object]]::new()
    foreach ($item in $sourceItems) { $sources[(Get-RelativePath $srcRoot $item.FullName)]=$item }
    foreach ($item in $destItems) { $destinations[(Get-RelativePath $dstRoot $item.FullName)]=$item }
    foreach ($rel in $sources.Keys) {
        $item=$sources[$rel]; $target=$destinations[$rel]
        if ($null -ne $target -and $item.PSIsContainer -ne $target.PSIsContainer) { throw "Source/destination type conflict: $rel" }
        if ($null -eq $target) {
            $changes.Add([pscustomobject]@{Action=$(if($item.PSIsContainer){'MKDIR'}else{'COPY'});Type=$(if($item.PSIsContainer){'DIR'}else{'FILE'});RelPath=$rel;ChangeAction='NEW'})
        } elseif (-not $item.PSIsContainer -and $Policy -ne 'MISSING_ONLY' -and (Test-FileNeedsCopy $item.FullName $target.FullName $item)) {
            $changes.Add([pscustomobject]@{Action='COPY';Type='FILE';RelPath=$rel;ChangeAction='UPDATE'})
        }
    }
    if ($Policy -eq 'STRICT') {
        foreach ($rel in $destinations.Keys) {
            if ($sources.ContainsKey($rel)) { continue }
            $item=$destinations[$rel]
            $changes.Add([pscustomobject]@{Action='DELETE';Type=$(if($item.PSIsContainer){'DIR'}else{'FILE'});RelPath=$rel;ChangeAction='DELETE'})
        }
    }
    # A disconnect or permission error must fail the whole preview, not yield a partial plan.
    if ((Get-ExactPathProbe $srcRoot).State -ne 'Exists' -or -not (Test-DestRootAvailable $dstRoot)) { throw 'Root became unavailable during scan' }
    return New-InternalMirrorScanResult @($changes.ToArray() | Sort-Object RelPath,Action)
}




function ConvertTo-ProcessArgumentString {
    param([string[]]$Arguments)
    $quoted = foreach ($argument in $Arguments) {
        $text=[string]$argument
        if ($text -notmatch '[\s"]' -and $text.Length -gt 0) { $text; continue }
        $text=[regex]::Replace($text,'(\\*)"','$1$1\"')
        $text=[regex]::Replace($text,'(\\+)$','$1$1')
        '"'+$text+'"'
    }
    return ($quoted -join ' ')
}





function Invoke-ApplyFileChanges {
    param([object]$Pair, [object[]]$FileChanges, [ValidateSet('STRICT','UPDATE_KEEP_EXTRAS','MISSING_ONLY')][string]$Policy)
    $results=[Collections.Generic.List[object]]::new()
    $files=[Collections.Generic.List[object]]::new()
    # Apply only previewed paths; creating a directory never copies an unpreviewed subtree.
    $ordered=@($FileChanges | Where-Object Action -eq 'MKDIR' | Sort-Object { Get-QueuePathDepth $_.RelPath }) +
        @($FileChanges | Where-Object Action -eq 'COPY') +
        @($FileChanges | Where-Object Action -eq 'DELETE' | Sort-Object { Get-QueuePathDepth $_.RelPath } -Descending)
    foreach ($change in $ordered) {
        if ($change.Action -eq 'DELETE' -and $Policy -ne 'STRICT') { continue }
        $entry=[pscustomobject]@{PairName=$Pair.Name;RelPath=$change.RelPath;Action=$(if($change.Action -eq 'DELETE'){'Delete'}else{'Upsert'});IsDirectory=($change.Type -eq 'DIR');Size=$null;Source='';Dest=''}
        if ($change.Action -eq 'COPY') { $files.Add($entry); continue }
        $result=Apply-OneEntry $entry -PairOverride $Pair -MissingOnly:($Policy -eq 'MISSING_ONLY') -MirrorDelete
        $results.Add($result)
    }
    if ($files.Count -gt 0) {
        $online=@{}; $online[$Pair.Name]=Test-DestRootAvailable $Pair.Dest
        $records=@(Invoke-ParallelFileTransfers @($files.ToArray()) $online $null @{} -PairOverride $Pair -MissingOnly:($Policy -eq 'MISSING_ONLY'))
        foreach ($record in $records) { $results.Add($record.Result) }
    }
    return @($results.ToArray())
}





function Test-PathInsideRoot {
    param([string]$Root, [string]$Path)
    try {
        $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
        $pathFull = [System.IO.Path]::GetFullPath($Path)
        if ([string]::IsNullOrWhiteSpace($rootFull) -or [string]::IsNullOrWhiteSpace($pathFull)) { return $false }
        $prefix = $rootFull + "\"
        return $pathFull.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
    } catch {
        return $false
    }
}





function Invoke-FullMirrorApplyResults {
    param([object[]]$Pairs, [object[]]$PreviewResults, [ValidateSet('STRICT','UPDATE_KEEP_EXTRAS','MISSING_ONLY')][string]$Policy)
    $results=[Collections.Generic.List[object]]::new()
    foreach ($preview in $PreviewResults) {
        if ($preview.Status -in @('ERROR','MISSING')) {
            $results.Add([pscustomobject]@{Pair=$preview.Name;Action='SCAN';Path='';Status='FAILED';Message=$preview.Message})
            continue
        }
        if ($preview.Status -ne 'CHANGED') { continue }
        $pair=@($Pairs | Where-Object Name -eq $preview.Name) | Select-Object -First 1
        if ($null -eq $pair) { throw 'Preview pair no longer exists' }
        foreach ($result in @(Invoke-ApplyFileChanges $pair @($preview.FileChanges) $Policy)) { $results.Add($result) }
    }
    if ($results.Count -eq 0) { Write-Color 'All pairs already match. Nothing to apply.' 'Green'; Wait-Back }
    else { Show-ApplyResults @($results.ToArray()) 'Full Mirror Apply Results' }
    Write-Log 'QUEUE' 'Pending queue preserved after Full Mirror; Apply Pending acknowledges matching entry IDs'
}

function Invoke-FullMirror {
    if (-not (Enter-ApplyLock -Operation "Full Mirror")) { return }
    try {
    $pairs = @(Get-Pairs)
    Show-Header "Full Mirror" "Dedicated full scan"
    if ($pairs.Count -eq 0) {
        Write-Color "No backup pairs configured. Add a pair first." "Yellow"
        Wait-Back
        return
    }
    $driveStatus = Test-AllDriveMapsOnline
    if (-not $driveStatus.Online) {
        Write-Color ("⚠  Drive " + ($driveStatus.OfflineDrives -join ", ") + " is not available. Full Mirror requires all destination drives.") "Yellow"
        Wait-Back
        return
    }
    Write-Color "Choose full mirror behavior:" "Cyan"
    Write-Color "# Makes destination match source exactly. Copies new files, updates changed files, and may delete extras." "DarkGray"
    Write-Color "[1] Strict Full Mirror" "Yellow"
    Write-Color "# Daily-safe full scan. Copies new files and updates changed files from source, but keeps destination extras." "DarkGray"
    Write-Color "[2] Update From Source, Keep Extras" "Yellow"
    Write-Color "# Most conservative. Copies missing source files only; does not update existing destination files." "DarkGray"
    Write-Color "[3] Safe Missing Only" "Yellow"
    Write-Color "[Esc] Back" "DarkGray"
    Write-Host ""
    $choice = Read-KeyChoice
    if ($null -eq $choice) { return }
    $policy = $null
    if ($choice -eq "1") { $policy = "STRICT" }
    elseif ($choice -eq "2") { $policy = "UPDATE_KEEP_EXTRAS" }
    elseif ($choice -eq "3") { $policy = "MISSING_ONLY" }
    else { return }

    Write-Color "[1] Show preview first, then apply" "Yellow"
    Write-Color "[2] Apply directly (skip preview)" "Yellow"
    Write-Color "[Esc] Back" "DarkGray"
    Write-Host ""
    $sub = Read-KeyChoice
    if ($null -eq $sub) { return }
    if ($sub -eq "2") {
        Show-Header "Full Mirror Apply" (Get-PolicyLabel $policy)
        $previewResults = Invoke-FullMirrorScan -Pairs $pairs -Preview:$true -Policy $policy
        $allMatched = ($previewResults | Where-Object { $_.Status -ne "MATCHED" }).Count -eq 0
        if ($allMatched) {
            Show-RobocopyResults -Results $previewResults -Title "Full Mirror Results" -Pause:$false
            Write-Host ""
            Write-Color "No changes are needed for the selected mirror mode." "Green"
            Wait-Back

            return
        }
        Invoke-FullMirrorApplyResults -Pairs $pairs -PreviewResults $previewResults -Policy $policy
        return
    }

    # Show preview
    Show-Header "Full Mirror Preview" (Get-PolicyLabel $policy)
    $previewResults = Invoke-FullMirrorScan -Pairs $pairs -Preview:$true -Policy $policy

    $allMatched = ($previewResults | Where-Object { $_.Status -ne "MATCHED" }).Count -eq 0
    if ($allMatched) {
        Show-RobocopyResults -Results $previewResults -Title "Full Mirror Preview" -Pause:$false
        Write-Host ""
        Write-Color "No changes are needed for the selected mirror mode." "Green"

        Wait-Back
        return
    }

    Show-RobocopyResults -Results $previewResults -Title "Full Mirror Preview" -Pause:$true
    Write-Host ""
    $ok = Read-EnterOrEsc "Apply these changes now?"
    if (-not $ok) { return }
    Show-Header "Full Mirror Apply" (Get-PolicyLabel $policy)
    Invoke-FullMirrorApplyResults -Pairs $pairs -PreviewResults $previewResults -Policy $policy
    } finally {
        $script:PendingSessionSnapshot = $null
        Exit-ApplyLock
    }
}

function Get-PolicyLabel {
    param([string]$Policy)
    if ($Policy -eq "STRICT") { return "Strict Full Mirror" }
    if ($Policy -eq "UPDATE_KEEP_EXTRAS") { return "Update From Source, Keep Extras" }
    return "Safe Missing Only"
}

function Get-PolicyShort {
    param([string]$Policy)
    if ($Policy -eq "STRICT") { return "STRICT" }
    if ($Policy -eq "UPDATE_KEEP_EXTRAS") { return "UPDATE" }
    return "MISS"
}









function New-FullMirrorErrorResult {
    param([object]$Pair, [bool]$Preview, [string]$Policy, [string]$Status, [string]$Message)
    return [pscustomobject]@{
        Name=$Pair.Name; Mode=$(if($Preview){"PREVIEW"}else{"APPLY"}); Policy=(Get-PolicyShort $Policy); Status=$Status; Code=16; Time=0
        FilesTotal=0; NewFiles=0; NewDirs=0; UpdatedFiles=0; FilesSkipped=0; ExtraItems=0; FilesFailed=0; Message=$Message; Changes=@(); FileChanges=@()
    }
}

function Invoke-FullMirrorScan {
    param([object[]]$Pairs, [bool]$Preview, [ValidateSet('STRICT','UPDATE_KEEP_EXTRAS','MISSING_ONLY')][string]$Policy)
    $limit=[math]::Max(1,[math]::Min(32,[int]$script:Config.RobocopyParallelBatches))
    $pool=[runspacefactory]::CreateRunspacePool(1,$limit)
    $jobs=[Collections.Generic.List[object]]::new()
    $results=[Collections.Generic.List[object]]::new()
    $worker={
        param($ScriptPath,$ConfigJson,$Pair,$Policy)
        . $ScriptPath
        $ErrorActionPreference='Stop'
        $script:Config=$ConfigJson | ConvertFrom-Json
        $scan=Get-InternalMirrorScan $Pair $Policy
        return $scan
    }
    try {
        $pool.Open(); $next=0
        while ($next -lt $Pairs.Count -or $jobs.Count -gt 0) {
            while ($next -lt $Pairs.Count -and $jobs.Count -lt $limit) {
                $pair=$Pairs[$next]; $next++
                $ps=[powershell]::Create(); $ps.RunspacePool=$pool
                [void]$ps.AddScript($worker.ToString()).AddArgument($script:ScriptPath).AddArgument(($script:Config | ConvertTo-Json -Depth 50)).AddArgument($pair).AddArgument($Policy)
                try { $jobs.Add([pscustomobject]@{Shell=$ps;Handle=$ps.BeginInvoke();Pair=$pair;Timer=[Diagnostics.Stopwatch]::StartNew()}) }
                catch { $ps.Dispose(); throw }
            }
            foreach ($job in @($jobs.ToArray())) {
                if (-not $job.Handle.IsCompleted) { continue }
                try {
                    $output=@($job.Shell.EndInvoke($job.Handle))
                    if ($job.Shell.HadErrors -or $output.Count -ne 1) { throw ($job.Shell.Streams.Error | Out-String) }
                    $scan=$output[0]; $c=$scan.ChangeSummary
                    $results.Add([pscustomobject]@{Name=$job.Pair.Name;Mode='PREVIEW';Policy=(Get-PolicyShort $Policy);Status=$(if($scan.HasChanges){'CHANGED'}else{'MATCHED'});Code=0;Time=[math]::Round($job.Timer.Elapsed.TotalSeconds,1);NewFiles=$c.NewFiles;NewDirs=$c.NewDirs;UpdatedFiles=$c.UpdatedFiles;FilesSkipped=0;ExtraItems=($c.ExtraFiles+$c.ExtraDirs);FilesTotal=@($scan.FileChanges).Count;FilesFailed=0;Message='';Changes=$scan.Changes;FileChanges=$scan.FileChanges})
                } catch { $results.Add((New-FullMirrorErrorResult $job.Pair $true $Policy 'ERROR' $_.Exception.Message)) }
                finally { $job.Shell.Dispose(); [void]$jobs.Remove($job) }
            }
            if ($jobs.Count -gt 0) { Start-Sleep -Milliseconds 50 }
        }
    } finally {
        foreach ($job in @($jobs.ToArray())) { try { $job.Shell.Stop() } finally { $job.Shell.Dispose() } }
        $pool.Dispose()
    }
    return @($results.ToArray() | Sort-Object Name)
}

function Show-RobocopyResults {
    param([object[]]$Results, [string]$Title, [bool]$Pause = $true)
    Show-Header $Title "Full Mirror comparison"
    $wPair = 18; $wPolicy = 7; $wStatus = 7; $wTotal = 6; $wNew = 5; $wUpdate = 6; $wSkip = 6; $wExtra = 6; $wFail = 5; $wTime = 6
    $line = "+" + ("-"*($wPair+2)) + "+" + ("-"*($wPolicy+2)) + "+" + ("-"*($wStatus+2)) + "+" + ("-"*($wTotal+2)) + "+" + ("-"*($wNew+2)) + "+" + ("-"*($wUpdate+2)) + "+" + ("-"*($wSkip+2)) + "+" + ("-"*($wExtra+2)) + "+" + ("-"*($wFail+2)) + "+" + ("-"*($wTime+2)) + "+"
    Write-Color $line "DarkGray"
    Write-Color ("| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} |" -f (Center-Text "Pair" $wPair),(Center-Text "Mode" $wPolicy),(Center-Text "Status" $wStatus),(Center-Text "Total" $wTotal),(Center-Text "New" $wNew),(Center-Text "Upd" $wUpdate),(Center-Text "Skip" $wSkip),(Center-Text "Extra" $wExtra),(Center-Text "Fail" $wFail),(Center-Text "Time" $wTime)) "DarkGray"
    Write-Color $line "DarkGray"
    foreach ($r in $Results) {
        $color = if ($r.Status -eq "MATCHED") { "Green" } elseif ($r.Status -eq "ERROR" -or $r.Status -eq "MISSING") { "Red" } else { "Yellow" }
        Write-Color "| " "DarkGray" -NoNewLine
        Write-Color (Fit-Cell $r.Name $wPair) "Cyan" -NoNewLine
        Write-Color " | " "DarkGray" -NoNewLine
        Write-Color (Center-Text $r.Policy $wPolicy) "Yellow" -NoNewLine
        Write-Color " | " "DarkGray" -NoNewLine
        Write-Color (Center-Text $r.Status $wStatus) $color -NoNewLine
        Write-Color " | " "DarkGray" -NoNewLine
        Write-Color (Center-Text ([string]$r.FilesTotal) $wTotal) "White" -NoNewLine
        Write-Color " | " "DarkGray" -NoNewLine
        $newCombined = $r.NewFiles + $r.NewDirs
        Write-Color (Center-Text ([string]$newCombined) $wNew) $(if ($newCombined -gt 0) { "Yellow" } else { "DarkGray" }) -NoNewLine
        Write-Color " | " "DarkGray" -NoNewLine
        Write-Color (Center-Text ([string]$r.UpdatedFiles) $wUpdate) $(if ($r.UpdatedFiles -gt 0) { "Yellow" } else { "DarkGray" }) -NoNewLine
        Write-Color " | " "DarkGray" -NoNewLine
        Write-Color (Center-Text ([string]$r.FilesSkipped) $wSkip) "Green" -NoNewLine
        Write-Color " | " "DarkGray" -NoNewLine
        Write-Color (Center-Text ([string]$r.ExtraItems) $wExtra) $(if ($r.ExtraItems -gt 0) { "DarkYellow" } else { "DarkGray" }) -NoNewLine
        Write-Color " | " "DarkGray" -NoNewLine
        Write-Color (Center-Text ([string]$r.FilesFailed) $wFail) $(if ($r.FilesFailed -gt 0) { "Red" } else { "DarkGray" }) -NoNewLine
        Write-Color " | " "DarkGray" -NoNewLine
        Write-Color (Center-Text ("{0}s" -f $r.Time) $wTime) "DarkGray" -NoNewLine
        Write-Color " |" "DarkGray"
    }
    Write-Color $line "DarkGray"
    Write-Host ""
    Write-Color "Total = New + Upd + Extra. New = missing files & folders. Upd = source updates. Extra = destination-only files/folders." "DarkGray"
    Write-Color "Excluded files and internal staging paths are protected. Failed deletes require review." "DarkGray"
    Write-Color "STRICT deletes Extra. UPDATE keeps Extra. MISSING ignores Upd and Extra." "DarkGray"
    Write-Host ""
    $detailShown = $false
    foreach ($r in $Results) {
        if ($r.Mode -ne "PREVIEW") { continue }
        if ($r.Status -ne "CHANGED") { continue }
        $hasFC = ($null -ne $r.FileChanges -and $r.FileChanges.Count -gt 0)
        $hasCh = ($null -ne $r.Changes -and $r.Changes.Count -gt 0)
        if (-not $hasFC -and -not $hasCh) { continue }
        if (-not $detailShown) {
            Write-Color "=== Detailed Changes ===" "Cyan"
            $detailShown = $true
        }
        $count = if ($hasFC) { $r.FileChanges.Count } else { $r.Changes.Count }
        $maxShow = [Math]::Min($count, 50)
        Write-Color ("[{0}] {1} change(s):" -f $r.Name, $count) "Yellow"
        if ($hasFC) {
            $wAction = 8; $wKind = 6; $wPath = 66
            $tLine = "+" + ("-"*($wAction+2)) + "+" + ("-"*($wKind+2)) + "+" + ("-"*($wPath+2)) + "+"
            Write-Color $tLine "DarkGray"
            Write-Color ("| {0} | {1} | {2} |" -f (Center-Text "Action" $wAction),(Center-Text "Kind" $wKind),(Center-Text "Path" $wPath)) "DarkGray"
            Write-Color $tLine "DarkGray"
            $isStrict = ($r.Policy -eq "STRICT")
            for ($i = 0; $i -lt $maxShow; $i++) {
                $fc = $r.FileChanges[$i]
                $label = switch ($fc.ChangeAction) {
                    "NEW"    { "NEW" }
                    "UPDATE" { "UPDATE" }
                    "DELETE" { if ($isStrict) { "DELETE" } else { "EXTRA" } }
                    default  { $fc.Action }
                }
                $kind = $fc.Type
                $path = Fit-Cell $fc.RelPath $wPath
                $color = if ($fc.ChangeAction -eq "DELETE") { "DarkYellow" } elseif ($fc.ChangeAction -eq "NEW") { "Green" } else { "Yellow" }
                Write-Color "| " "DarkGray" -NoNewLine
                Write-Color (Center-Text $label $wAction) $color -NoNewLine
                Write-Color " | " "DarkGray" -NoNewLine
                Write-Color (Center-Text $kind $wKind) "White" -NoNewLine
                Write-Color " | " "DarkGray" -NoNewLine
                Write-Color $path "White" -NoNewLine
                Write-Color " |" "DarkGray"
            }
            Write-Color $tLine "DarkGray"
        } else {
            for ($i = 0; $i -lt $maxShow; $i++) {
                Write-Color ("  -> " + $r.Changes[$i]) "DarkGray"
            }
        }
        if ($count -gt $maxShow) {
            Write-Color ("  ... and {0} more" -f ($count - $maxShow)) "DarkYellow"
        }
    }
    if ($Pause) { Wait-Back }
}

function Show-Status {
    Show-Header "Status" "Configuration and queue"
    $entries = @(Read-QueueEntries)
    $latest = @(Get-LatestQueueEntries $entries)
    Write-Color ("Script      : " + $script:ScriptPath) "DarkGray"
    Write-Color ("Config      : " + $script:ConfigPath) "DarkGray"
    Write-Color ("Data folder : " + $script:DataDir) "DarkGray"
    Write-Color ("Queue file  : " + $script:QueuePath) "DarkGray"
    Write-Color ("Log file    : " + $script:LogPath) "DarkGray"
    Write-Host ""
    $task = Get-OwnedScheduledTask -TaskName ([string]$script:Config.TaskName)
    $watchers = @(Get-WatcherProcesses)
    Write-Color ("Pairs               : " + (Get-Pairs).Count) "Yellow"
    Write-Color ("Raw queue entries   : " + $entries.Count) "Yellow"
    Write-Color ("Effective entries   : " + $latest.Count) "Yellow"
    Write-Color ("Scheduled task      : " + $(if ($null -ne $task) { $task.State } else { "Not installed" })) $(if ($null -ne $task -and $task.State -eq "Running") { "Green" } else { "Yellow" })
    Write-Color ("Watcher processes   : " + $watchers.Count) $(if ($watchers.Count -gt 0) { "Green" } else { "Yellow" })
    Write-Host ""
    foreach ($pair in Get-Pairs) {
        $srcOk = Test-Path -LiteralPath $pair.Source -PathType Container
        $dstOk = Test-DestRootAvailableFast $pair.Dest
        $color = if ($srcOk -and $dstOk) { "Green" } else { "DarkYellow" }
        Write-Color ("[{0}] {1}" -f ($(if($srcOk -and $dstOk){"OK"}else{"WARN"}), $pair.Name)) $color
        Write-Color ("  Source: " + $pair.Source) "DarkGray"
        Write-Color ("  Dest  : " + (Resolve-DestinationPath $pair.Dest)) "DarkGray"
    }
    Wait-Back
}

function Show-Pairs {
    $pairs = @(Get-Pairs)
    if ($pairs.Count -eq 0) {
        Write-Color "No pairs configured." "Yellow"
        return
    }
    for ($i = 0; $i -lt $pairs.Count; $i++) {
        $p = $pairs[$i]
        Write-Color ("[{0}] {1}" -f ($i+1), $p.Name) "Yellow"
        Write-Color ("    Source: " + $p.Source) "DarkGray"
        Write-Color ("    Dest  : " + $p.Dest) "DarkGray"
    }
}

function Manage-PathsMenu {
    while ($true) {
        Show-Header "Manage Paths" "Esc = back"
        Show-Pairs
        Write-Host ""
        Write-Color "[1] Add pair" "Yellow"
        Write-Color "[2] Edit pair" "Yellow"
        Write-Color "[3] Remove pair" "Yellow"
        Write-Color "[Esc] Back" "DarkGray"
        Write-Host ""
        $choice = Read-KeyChoice
        if ($null -eq $choice) { return }
        switch ($choice) {
            "1" { Add-Pair }
            "2" { Edit-Pair }
            "3" { Remove-Pair }
        }
    }
}

function Add-Pair {
    Show-Header "Add Pair" "Esc = cancel"
    Write-Color "Only enter paths. The pair name is detected automatically." "DarkGray"
    Write-Color "Example source: C:\Users\YourName\Desktop\Projects\ClientA" "DarkGray"
    Write-Host ""
    $source = Read-LineOrEsc "Source path: "
    if ($null -eq $source -or [string]::IsNullOrWhiteSpace($source)) { return }
    $dest = Read-LineOrEsc "Destination path: "
    if ($null -eq $dest -or [string]::IsNullOrWhiteSpace($dest)) { return }
    $source = Normalize-PathText $source
    $dest = Normalize-PathText $dest
    $name = Get-AutoPairName -Source $source -Dest $dest
    Write-Host ""
    Write-Color ("Detected name: " + $name) "Green"
    Write-Color ("Source       : " + $source) "DarkGray"
    Write-Color ("Destination  : " + $dest) "DarkGray"
    Write-Host ""
    if (-not (Read-EnterOrEsc "Press Enter to save this pair, or Esc to cancel.")) { return }
    $pairs = @(Get-Pairs)
    $baseName=$name; $suffix=2
    while (@($pairs | Where-Object { $_.Name -ieq $name }).Count -gt 0) { $name="$baseName ($suffix)"; $suffix++ }
    $newPair=[pscustomobject]@{Name=$name;Source=$source;Dest=$dest}
    Assert-PairLayout $newPair
    $pairs += $newPair
    Set-Pairs $pairs
    Set-MapArray "PairExcludeDirs" $name @()
    Set-MapArray "PairExcludeFiles" $name @()
    Save-Config
    Show-SpinnerLine "Saving pair" 8
}

function Select-PairIndex {
    Show-Pairs
    Write-Host ""
    $num = Read-NumberOrEsc "Pair number: "
    if ($null -eq $num) { return -1 }
    $pairs = @(Get-Pairs)
    $idx = $num - 1
    if ($idx -lt 0 -or $idx -ge $pairs.Count) { return -1 }
    return $idx
}

function Edit-Pair {
    Show-Header "Edit Pair" "Esc = cancel"
    $pairs = @(Get-Pairs)
    $idx = Select-PairIndex
    if ($idx -lt 0) { return }
    $p = $pairs[$idx]
    Write-Color "Leave a field empty to keep the current value." "DarkGray"
    Write-Color "Name is auto-detected when the source or destination changes." "DarkGray"
    $source = Read-LineOrEsc ("Source [{0}]: " -f $p.Source)
    if ($null -eq $source) { return }
    $dest = Read-LineOrEsc ("Destination [{0}]: " -f $p.Dest)
    if ($null -eq $dest) { return }
    $oldName = [string]$p.Name
    if (-not [string]::IsNullOrWhiteSpace($source)) { $p.Source = Normalize-PathText $source }
    if (-not [string]::IsNullOrWhiteSpace($dest)) { $p.Dest = Normalize-PathText $dest }
    # Pair names are stable identifiers for pending work and exclusion maps.
    if ($oldName -ne $p.Name) {
        Set-MapArray "PairExcludeDirs" $p.Name @(Get-MapArray "PairExcludeDirs" $oldName)
        Set-MapArray "PairExcludeFiles" $p.Name @(Get-MapArray "PairExcludeFiles" $oldName)
    }
    Set-Pairs $pairs
    Save-Config
}

function Remove-Pair {
    Show-Header "Remove Pair" "Esc = cancel"
    $pairs = @(Get-Pairs)
    $idx = Select-PairIndex
    if ($idx -lt 0) { return }
    Write-Color ("Remove pair: " + $pairs[$idx].Name) "Red"
    if (-not (Read-EnterOrEsc "Press Enter to remove, or Esc to cancel.")) { return }
    $newPairs = @()
    for ($i = 0; $i -lt $pairs.Count; $i++) {
        if ($i -ne $idx) { $newPairs += $pairs[$i] }
    }
    Set-Pairs $newPairs
    Save-Config
}

function Add-SmartExclusion {
    Show-Header "Smart Add Exclusion" "Paste a path - auto-detects everything"
    $rawPath = Read-LineOrEsc "Path: "
    if ($null -eq $rawPath -or [string]::IsNullOrWhiteSpace($rawPath)) { return }
    $fullPath = Normalize-PathText $rawPath
    if (-not (Test-Path -LiteralPath $fullPath)) {
        Write-Color "Path does not exist. Cannot detect file/folder type." "Yellow"
        $isDir = $false
        $typeLabel = "file"
    } else {
        $isDir = Test-Path -LiteralPath $fullPath -PathType Container
        $typeLabel = if ($isDir) { "folder" } else { "file" }
    }
    $matchedPair = $null
    $relativePath = $null
    $leafName = Split-Path -Leaf $fullPath
    foreach ($p in Get-Pairs) {
        $src = Normalize-PathText $p.Source
        if (Test-PathInsideRoot $src $fullPath) {
            $matchedPair = $p
            if ($fullPath.Length -gt $src.Length) { $relativePath = $fullPath.Substring($src.Length).TrimStart('\') }
            break
        }
    }
    if ($null -ne $matchedPair) {
        $exclValue = if ($relativePath) { $relativePath } else { $leafName }
        Write-Color ("Pair: " + $matchedPair.Name) "Green"
        Write-Color ("Type: " + $typeLabel) "Green"
        Write-Color ("Value: " + $exclValue) "Green"
        Write-Host ""
        Write-Color "Enter = add as pair exclusion   Esc = add as global" "DarkGray"
        Write-Color "Space = cancel" "DarkGray"
        while ($true) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq [ConsoleKey]::Enter) {
                $mapName = if ($isDir) { "PairExcludeDirs" } else { "PairExcludeFiles" }
                $arr = @(Get-MapArray $mapName $matchedPair.Name)
                if ($arr -notcontains $exclValue) { $arr += $exclValue }
                Set-MapArray $mapName $matchedPair.Name $arr
                Save-Config
                Write-Color ("Added pair exclusion: " + $exclValue) "Green"
                Wait-Back
                return
            }
            if ($key.Key -eq [ConsoleKey]::Escape) { break }
            if ($key.Key -eq [ConsoleKey]::Spacebar) { return }
        }
    }
    $name = $leafName
    $propName = if ($isDir) { "GlobalExcludeDirs" } else { "GlobalExcludeFiles" }
    Write-Color ("Adding as global " + $typeLabel + " exclusion: " + $name) "DarkYellow"
    $arr = @(Get-Array $script:Config.PSObject.Properties[$propName].Value)
    if ($arr -notcontains $name) { $arr += $name }
    $script:Config | Add-Member -NotePropertyName $propName -NotePropertyValue @($arr) -Force
    Save-Config
    Write-Color ("Added global exclusion: " + $name) "Green"
    Wait-Back
}

function Manage-ExclusionsMenu {
    while ($true) {
        Show-Header "Manage Exclusions" "Esc = back"
        Write-Color "[1] Smart add exclusion" "Yellow"
        Write-Color "    Paste a path - auto-detects pair, type and scope." "DarkGray"
        Write-Color "[2] Add global folder exclusion" "Yellow"
        Write-Color "    Skips this folder name/path in every pair." "DarkGray"
        Write-Color "[3] Add global file exclusion" "Yellow"
        Write-Color "    Skips this file name or pattern in every pair." "DarkGray"
        Write-Color "[4] Add pair folder exclusion" "Yellow"
        Write-Color "    Skips a folder only inside one selected pair." "DarkGray"
        Write-Color "[5] Add pair file exclusion" "Yellow"
        Write-Color "    Skips a file or pattern only inside one selected pair." "DarkGray"
        Write-Color "[6] Remove exclusion" "Yellow"
        Write-Color "    Shows all exclusions and removes the selected one." "DarkGray"
        Write-Color "[7] Show exclusions" "Yellow"
        Write-Color "    Lists global and pair-specific exclusions currently saved." "DarkGray"
        Write-Color "[Esc] Back" "DarkGray"
        Write-Host ""
        $choice = Read-KeyChoice
        if ($null -eq $choice) { return }
        switch ($choice) {
            "1" { Add-SmartExclusion }
            "2" { Add-GlobalExclusion "GlobalExcludeDirs" }
            "3" { Add-GlobalExclusion "GlobalExcludeFiles" }
            "4" { Add-PairExclusion "PairExcludeDirs" }
            "5" { Add-PairExclusion "PairExcludeFiles" }
            "6" { Remove-Exclusion }
            "7" { Show-Exclusions; Wait-Back }
        }
    }
}

function Add-GlobalExclusion {
    param([string]$PropName)
    Show-Header "Add Exclusion" "Esc = cancel"
    $value = Read-LineOrEsc "Value: "
    if ($null -eq $value -or [string]::IsNullOrWhiteSpace($value)) { return }
    $arr = @(Get-Array $script:Config.PSObject.Properties[$PropName].Value)
    if ($arr -notcontains $value.Trim()) { $arr += $value.Trim() }
    $script:Config | Add-Member -NotePropertyName $PropName -NotePropertyValue @($arr) -Force
    Save-Config
}

function Add-PairExclusion {
    param([string]$MapName)
    Show-Header "Add Pair Exclusion" "Esc = cancel"
    $pairs = @(Get-Pairs)
    $idx = Select-PairIndex
    if ($idx -lt 0) { return }
    $value = Read-LineOrEsc "Value: "
    if ($null -eq $value -or [string]::IsNullOrWhiteSpace($value)) { return }
    $pairName = [string]$pairs[$idx].Name
    $arr = @(Get-MapArray $MapName $pairName)
    if ($arr -notcontains $value.Trim()) { $arr += $value.Trim() }
    Set-MapArray $MapName $pairName $arr
    Save-Config
}

function Get-ExclusionEntries {
    $entries = @()
    foreach ($prop in @("GlobalExcludeDirs","GlobalExcludeFiles")) {
        $kind = if ($prop -eq "GlobalExcludeDirs") { "DIR" } else { "FILE" }
        $arr = @(Get-Array $script:Config.PSObject.Properties[$prop].Value)
        for ($i = 0; $i -lt $arr.Count; $i++) {
            $entries += [pscustomobject]@{ Scope="GLOBAL"; Kind=$kind; Pair=""; Map=$prop; Index=$i; Value=$arr[$i] }
        }
    }
    foreach ($mapName in @("PairExcludeDirs","PairExcludeFiles")) {
        $kind = if ($mapName -eq "PairExcludeDirs") { "DIR" } else { "FILE" }
        $map = $script:Config.PSObject.Properties[$mapName].Value
        foreach ($prop in $map.PSObject.Properties) {
            $arr = @(Get-Array $prop.Value)
            for ($i = 0; $i -lt $arr.Count; $i++) {
                $entries += [pscustomobject]@{ Scope="PAIR"; Kind=$kind; Pair=$prop.Name; Map=$mapName; Index=$i; Value=$arr[$i] }
            }
        }
    }
    return $entries
}

function Show-Exclusions {
    Show-Header "Exclusions" "Current configuration"
    $entries = @(Get-ExclusionEntries)
    if ($entries.Count -eq 0) {
        Write-Color "No exclusions configured." "Yellow"
        return
    }
    for ($i = 0; $i -lt $entries.Count; $i++) {
        $e = $entries[$i]
        $pair = if ([string]::IsNullOrWhiteSpace($e.Pair)) { "-" } else { $e.Pair }
        Write-Color ("[{0}] {1,-6} {2,-4} {3,-20} {4}" -f ($i+1), $e.Scope, $e.Kind, $pair, $e.Value) "Yellow"
    }
}

function Remove-Exclusion {
    Show-Exclusions
    Write-Host ""
    $entries = @(Get-ExclusionEntries)
    if ($entries.Count -eq 0) { Wait-Back; return }
    $num = Read-NumberOrEsc "Item number to remove: "
    if ($null -eq $num) { return }
    $idx = $num - 1
    if ($idx -lt 0 -or $idx -ge $entries.Count) { return }
    $e = $entries[$idx]
    if ($e.Scope -eq "GLOBAL") {
        $arr = @(Get-Array $script:Config.PSObject.Properties[$e.Map].Value)
        $new = @()
        for ($i = 0; $i -lt $arr.Count; $i++) { if ($i -ne $e.Index) { $new += $arr[$i] } }
        $script:Config | Add-Member -NotePropertyName $e.Map -NotePropertyValue @($new) -Force
    } else {
        $arr = @(Get-MapArray $e.Map $e.Pair)
        $new = @()
        for ($i = 0; $i -lt $arr.Count; $i++) { if ($i -ne $e.Index) { $new += $arr[$i] } }
        Set-MapArray $e.Map $e.Pair $new
    }
    Save-Config
}

function SettingsMenu {
    while ($true) {
        Show-Header "Settings" "Esc = back"
        Write-Color "[1] DebounceMs              = " "Yellow" -NoNewLine; Write-Color $script:Config.DebounceMs "Cyan" -NoNewLine; Write-Color "   # Delay before queuing a change (ms)" "DarkGray"
        Write-Color "[2] WatchBufferKB           = " "Yellow" -NoNewLine; Write-Color $script:Config.WatchBufferKB "Cyan" -NoNewLine; Write-Color "   # Watcher internal buffer size (KB)" "DarkGray"
        Write-Color "[3] RobocopyThreads         = " "Yellow" -NoNewLine; Write-Color $script:Config.RobocopyThreads "Cyan" -NoNewLine; Write-Color "   # Parallel copy threads (/MT)" "DarkGray"
        Write-Color "[4] RobocopyRetries         = " "Yellow" -NoNewLine; Write-Color $script:Config.RobocopyRetries "Cyan" -NoNewLine; Write-Color "   # Retry count on failure (/R)" "DarkGray"
        Write-Color "[5] RobocopyWaitSeconds     = " "Yellow" -NoNewLine; Write-Color $script:Config.RobocopyWaitSeconds "Cyan" -NoNewLine; Write-Color "   # Wait between retries in seconds (/W)" "DarkGray"
        Write-Color "[6] RobocopyParallelBatches = " "Yellow" -NoNewLine; Write-Color $script:Config.RobocopyParallelBatches "Cyan" -NoNewLine; Write-Color "   # Concurrent pairs during Full Mirror" "DarkGray"
        Write-Color "[7] ParallelFileTransfers   = " "Yellow" -NoNewLine; Write-Color $script:Config.ParallelFileTransfers "Cyan" -NoNewLine; Write-Color "   # Concurrent files during Apply Pending (1-32)" "DarkGray"
        Write-Color "[8] DeleteDestOnSourceDelete= " "Yellow" -NoNewLine; Write-Color $script:Config.DeleteDestOnSourceDelete "Cyan" -NoNewLine; Write-Color "   # Delete dest file if source is deleted" "DarkGray"
        Write-Color "[9] DataDir                 = " "Yellow" -NoNewLine; Write-Color $script:Config.DataDir "Cyan" -NoNewLine; Write-Color "   # Program data folder" "DarkGray"
        Write-Color "[D] Manage Drive Maps" "Yellow"
        Write-Color "[Esc] Back" "DarkGray"
        Write-Host ""
        $choice = Read-KeyChoice
        if ($null -eq $choice) { return }
        switch ($choice) {
            "1" { Set-IntSetting "DebounceMs" 0 }
            "2" { Set-IntSetting "WatchBufferKB" 4 }
            "3" { Set-IntSetting "RobocopyThreads" 1 }
            "4" { Set-IntSetting "RobocopyRetries" 0 }
            "5" { Set-IntSetting "RobocopyWaitSeconds" 0 }
            "6" { Set-IntSetting "RobocopyParallelBatches" 1 }
            "7" { Set-RangedIntSetting "ParallelFileTransfers" 1 32 }
            "8" { Toggle-BoolSetting "DeleteDestOnSourceDelete" }
            "9" { Set-StringSetting "DataDir" }
            { $_ -ieq "D" } { Manage-DriveMapsMenu }
        }
    }
}

function Manage-DriveMapsMenu {
    while ($true) {
        Show-Header "Manage Drive Maps" "Esc = back"
        $maps = $script:Config.DriveMaps
        $props = @($maps.PSObject.Properties)
        if ($props.Count -eq 0) {
            Write-Color "No drive maps configured." "Yellow"
        } else {
            for ($i = 0; $i -lt $props.Count; $i++) {
                Write-Color ("[{0}] {1} => {2}" -f ($i+1), $props[$i].Name, $props[$i].Value) "Yellow"
            }
        }
        Write-Host ""
        Write-Color "[1] Add or update map" "Yellow"
        Write-Color "[2] Remove map" "Yellow"
        Write-Color "[Esc] Back" "DarkGray"
        Write-Host ""
        $choice = Read-KeyChoice
        if ($null -eq $choice) { return }
        switch ($choice) {
            "1" { Add-OrUpdateDriveMap }
            "2" { Remove-DriveMap }
        }
    }
}

function Add-OrUpdateDriveMap {
    Show-Header "Add Drive Map" "Example: Z: => \\server\share"
    $drive = Read-LineOrEsc "Drive name: "
    if ($null -eq $drive -or [string]::IsNullOrWhiteSpace($drive)) { return }
    $target = Read-LineOrEsc "UNC target: "
    if ($null -eq $target -or [string]::IsNullOrWhiteSpace($target)) { return }
    $script:Config.DriveMaps | Add-Member -NotePropertyName $drive.Trim() -NotePropertyValue $target.Trim() -Force
    Save-Config
}

function Remove-DriveMap {
    Show-Header "Remove Drive Map" "Esc = cancel"
    $props = @($script:Config.DriveMaps.PSObject.Properties)
    if ($props.Count -eq 0) {
        Write-Color "No drive maps configured." "Yellow"
        Wait-Back
        return
    }
    for ($i = 0; $i -lt $props.Count; $i++) {
        Write-Color ("[{0}] {1} => {2}" -f ($i+1), $props[$i].Name, $props[$i].Value) "Yellow"
    }
    Write-Host ""
    $num = Read-NumberOrEsc "Map number: "
    if ($null -eq $num) { return }
    $idx = $num - 1
    if ($idx -lt 0 -or $idx -ge $props.Count) { return }
    $script:Config.DriveMaps.PSObject.Properties.Remove($props[$idx].Name)
    Save-Config
}

function Set-IntSetting {
    param([string]$Name, [int]$Min)
    Show-Header "Set $Name" "Esc = cancel"
    $value = Read-LineOrEsc "New value: "
    if ($null -eq $value -or [string]::IsNullOrWhiteSpace($value)) { return }
    $n = 0
    if ([int]::TryParse($value, [ref]$n) -and $n -ge $Min) {
        $script:Config.PSObject.Properties[$Name].Value = $n
        Save-Config
    } else {
        Write-Color "Invalid number." "Red"
        Wait-Back
    }
}

function Set-RangedIntSetting {
    param([string]$Name, [int]$Min, [int]$Max)
    Show-Header "Set $Name" "Esc = cancel"
    $value = Read-LineOrEsc "New value ($Min-$Max): "
    if ($null -eq $value -or [string]::IsNullOrWhiteSpace($value)) { return }
    $n = 0
    if ([int]::TryParse($value, [ref]$n) -and $n -ge $Min -and $n -le $Max) {
        $script:Config.PSObject.Properties[$Name].Value = $n
        Save-Config
    } else {
        Write-Color ("Invalid number. Enter a value from {0} to {1}." -f $Min, $Max) "Red"
        Wait-Back
    }
}

function Set-StringSetting {
    param([string]$Name)
    Show-Header "Set $Name" "Esc = cancel"
    $value = Read-LineOrEsc "New value: "
    if ($null -eq $value -or [string]::IsNullOrWhiteSpace($value)) { return }
    $script:Config.PSObject.Properties[$Name].Value = $value.Trim()
    Save-Config
    Initialize-App -ReadOnly:($Mode -in @("PreviewPending","Status"))
}

function Toggle-BoolSetting {
    param([string]$Name)
    $script:Config.PSObject.Properties[$Name].Value = -not [bool]$script:Config.PSObject.Properties[$Name].Value
    Save-Config
}

function Install-Required {
    Show-Header "Install Required" "Scheduled watcher task"
    if (-not (Test-IsAdministrator)) {
        Write-Color "Administrator permission is required to install the scheduled task." "Yellow"
        Write-Color "A UAC prompt will open now for this install step only." "DarkGray"
        Invoke-ElevatedMode "Install"
        Show-PostElevatedTaskStatus "Install"
        return
    }
    New-Item -ItemType Directory -Path $script:DataDir -Force | Out-Null
    $taskName = [string]$script:Config.TaskName
    try {
        $existing=Get-ScheduledTask -TaskPath '\' -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -ceq $taskName }
        if ($null -ne $existing -and -not (Test-OwnedScheduledTask $existing)) { throw 'Task name belongs to another resource; choose a different TaskName' }
        Stop-KnownWatcherProcesses
        New-HiddenWatchLauncher
        Remove-KnownScheduledTasks -KeepTaskName $taskName
        $action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$script:HiddenWatchLauncherPath`""
        $trigger = New-ScheduledTaskTrigger -AtLogOn
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit ([timespan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
        $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "MiraQueue watcher" -Force -ErrorAction Stop | Out-Null
        Write-Color ("Scheduled task installed: " + $taskName) "Green"
        Start-ScheduledTask -TaskName $taskName -ErrorAction Stop
        Start-Sleep -Milliseconds 600
        $task = Get-OwnedScheduledTask -TaskName $taskName
        if ($null -ne $task) {
            Write-Color ("Scheduled task state: " + $task.State) "Green"
        }
        Write-Log "INFO" "Scheduled task installed"
    } catch {
        Write-Color ("Failed to install scheduled task: " + $_.Exception.Message) "Red"
        Write-Log "ERROR" "Install task failed: $($_.Exception.Message)"
    }
    Wait-Back
}

function New-HiddenWatchLauncher {
    $pointer=$script:ScriptDirPointerFile.Replace('"','""')
    $vbs=@"
Set fso = CreateObject("Scripting.FileSystemObject")
Set file = fso.OpenTextFile("$pointer", 1, False, -1)
scriptDir = file.ReadLine()
file.Close
psPath = scriptDir & "\MiraQueue.ps1"
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & psPath & """ -Mode Watch"
Set shell = CreateObject("WScript.Shell")
shell.Run cmd, 0, True
"@
    [IO.File]::WriteAllText($script:HiddenWatchLauncherPath,$vbs,[Text.Encoding]::Unicode)
}

function Test-RuntimePathProtected {
    param([string]$Path)
    $full=[IO.Path]::GetFullPath($Path).TrimEnd('\')
    foreach ($pair in @(Get-Pairs)) {
        foreach ($root in @($pair.Source,(Resolve-DestinationPath $pair.Dest))) {
            $protected=[IO.Path]::GetFullPath($root).TrimEnd('\')
            if ($full -ieq $protected -or (Test-PathInsideRoot $protected $full)) { return $true }
        }
    }
    return $false
}

function Remove-OwnedRuntimeData {
    # Exact known filenames only. Unknown files, directories and shortcuts are never inferred as ours.
    $paths=@($script:QueuePath,$script:QueueMetaPath,$script:LogPath,$script:ClearQueueRequestPath,$script:HiddenWatchLauncherPath,$script:ScriptDirPointerFile,$script:StopWatcherRequestPath)
    $logName=[regex]::Escape([IO.Path]::GetFileName($script:LogPath))
    foreach ($item in @(Get-ChildItem -LiteralPath $script:DataDir -File -Force -ErrorAction Stop)) {
        if ($item.Name -match ('^'+$logName+'\.\d{8}-\d{6}\.old$')) { $paths += $item.FullName }
    }
    foreach ($path in $paths) {
        if ([string]::IsNullOrWhiteSpace($path) -or (Test-RuntimePathProtected $path)) { continue }
        if (Test-PathInsideRoot $script:DataDir $path) { Remove-OwnedPath $script:DataDir $path }
    }
}

function Uninstall-Everything {
    Show-Header 'Uninstall Everything' 'Owned runtime files only; backup content is preserved'
    if (-not (Test-IsAdministrator)) { Invoke-ElevatedMode 'Uninstall'; return }
    if (-not (Read-EnterOrEsc 'Remove the configured watcher, queue, logs and configuration?')) { return }
    Stop-KnownWatcherProcesses
    if (-not (Enter-ApplyLock -Operation 'Uninstall')) { return }
    try {
        Remove-KnownScheduledTasks
        $queueMutex=Enter-QueueMutex
        if ($null -eq $queueMutex) { throw 'Uninstall cannot acquire queue lock' }
        try { Remove-OwnedRuntimeData } finally { Exit-QueueMutex $queueMutex }
        if (-not (Test-RuntimePathProtected $script:ConfigPath)) { Remove-OwnedPath $script:ScriptDir $script:ConfigPath }
    } finally { Exit-ApplyLock }
    # DataDir is never removed recursively, even under LOCALAPPDATA.
    if (-not (Test-RuntimePathProtected $script:ApplyLockPath)) {
        Remove-OwnedPath $script:DataDir $script:ApplyLockPath
    }
    if ([IO.Directory]::Exists($script:DataDir) -and -not (Test-RuntimePathProtected $script:DataDir) -and @(Get-ChildItem -LiteralPath $script:DataDir -Force -ErrorAction Stop).Count -eq 0) {
        [IO.Directory]::Delete($script:DataDir)
    }
    Write-Color 'Owned runtime files removed. Unrelated files and user-created shortcuts were preserved.' 'Green'
    Wait-Back
}

function Test-IsAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function Invoke-ElevatedMode {
    param([ValidateSet('Install','RemoveTask','Uninstall')][string]$TargetMode)
    try {
        $arguments=ConvertTo-ProcessArgumentString @('-NoProfile','-ExecutionPolicy','Bypass','-File',$script:ScriptPath,'-Mode',$TargetMode,'-NoPause')
        $process=Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -Verb RunAs -Wait -PassThru
        Write-Color ("Elevated operation exit code: " + $process.ExitCode) 'Yellow'
    } catch { Write-Color ("Elevation failed: " + $_.Exception.Message) 'Red' }
}

function Show-PostElevatedTaskStatus {
    param([ValidateSet("Install","RemoveTask","Uninstall")][string]$Operation)
    Start-Sleep -Milliseconds 800
    Write-Host ""
    if ($Operation -eq "Install") {
        $task = Get-OwnedScheduledTask -TaskName ([string]$script:Config.TaskName)
        $watchers = @(Get-WatcherProcesses)
        if ($null -ne $task) {
            Write-Color ("Scheduled task: " + $task.TaskName + " / " + $task.State) $(if ($task.State -eq "Running") { "Green" } else { "Yellow" })
        } else {
            Write-Color "Scheduled task was not found after install." "Red"
        }
        Write-Color ("Hidden watcher processes: " + $watchers.Count) $(if ($watchers.Count -gt 0) { "Green" } else { "Yellow" })
        Write-Color "Returning to menu in 3 seconds..." "DarkGray"
        Start-Sleep -Seconds 3
        return
    }

    $remaining = @(Get-OwnedScheduledTask -TaskName ([string]$script:Config.TaskName))
    $watchers = @(Get-WatcherProcesses)
    if ($remaining.Count -eq 0 -and $watchers.Count -eq 0) {
        Write-Color "Scheduled watcher removed." "Green"
    } else {
        Write-Color ("Remaining scheduled tasks: " + $remaining.Count) "Yellow"
        Write-Color ("Remaining watcher processes: " + $watchers.Count) "Yellow"
    }
    Write-Color "Returning to menu in 3 seconds..." "DarkGray"
    Start-Sleep -Seconds 3
}

function Remove-KnownScheduledTasks {
    param([string]$KeepTaskName = '')
    $name=[string]$script:Config.TaskName
    if ($name -eq $KeepTaskName) { return }
    $task=Get-OwnedScheduledTask $name
    if ($null -ne $task) {
        Unregister-ScheduledTask -InputObject $task -Confirm:$false -ErrorAction Stop
        Write-Color ("Removed scheduled task: " + $name) 'Green'
    }
}

function InstallMenu {
    while ($true) {
        Show-Header "Install / Uninstall" "Esc = back"
        Write-Color "[1] Install required scheduled watcher" "Yellow"
        Write-Color "[2] Remove scheduled watcher only" "Yellow"
        Write-Color "[3] Restart scheduled watcher" "Yellow"
        Write-Color "[4] Uninstall everything created by this program" "Yellow"
        Write-Color "[Esc] Back" "DarkGray"
        Write-Host ""
        $choice = Read-KeyChoice
        if ($null -eq $choice) { return }
        switch ($choice) {
            "1" { Install-Required }
            "2" { Remove-ScheduledWatcherOnly }
            "3" { Restart-ScheduledWatcher }
            "4" { Uninstall-Everything; return }
        }
    }
}

function Restart-ScheduledWatcher {
    Show-Header "Restart Scheduled Watcher" "Reload config and paths"
    Refresh-WatcherAfterConfigChange
    Wait-Back
}

function Remove-ScheduledWatcherOnly {
    Show-Header "Remove Scheduled Watcher" "Settings and queue are preserved"
    if (-not (Test-IsAdministrator)) {
        Write-Color "Administrator permission is required to remove scheduled tasks cleanly." "Yellow"
        Write-Color "A UAC prompt will open now for this removal step only." "DarkGray"
        Invoke-ElevatedMode "RemoveTask"
        Show-PostElevatedTaskStatus "RemoveTask"
        return
    }
    Stop-KnownWatcherProcesses
    Remove-KnownScheduledTasks -KeepTaskName ""
    if (Test-Path -LiteralPath $script:HiddenWatchLauncherPath) {
        Remove-OwnedPath $script:DataDir $script:HiddenWatchLauncherPath
        Write-Color ("Removed hidden watcher launcher: " + $script:HiddenWatchLauncherPath) "Green"
    }
    Write-Host ""
    Write-Color "Scheduled watcher removal finished. Config, queue, logs, sources, and destinations were not touched." "Green"
    Wait-Back
}

function Stop-KnownWatcherProcesses {
    $watchers=@(Get-WatcherProcesses)
    if ($watchers.Count -eq 0) { return }
    Write-AtomicText $script:StopWatcherRequestPath ([datetime]::UtcNow.ToString('o'))
    $deadline=[datetime]::UtcNow.AddSeconds(30)
    do {
        Start-Sleep -Milliseconds 200
        $remaining=@(Get-WatcherProcesses)
    } while ($remaining.Count -gt 0 -and [datetime]::UtcNow -lt $deadline)
    if ($remaining.Count -gt 0) { throw 'Watcher is still flushing or scanning. Retry after it stops; no process was forcibly killed.' }
}

function Get-WatcherProcesses {
    try {
        $filePattern = '(?i)(?:^|\s)-File\s+(?:"' + [regex]::Escape($script:ScriptPath) + '"|' + [regex]::Escape($script:ScriptPath) + ')(?=\s|$)'
        return @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" -ErrorAction Stop | Where-Object {
            $_.CommandLine -match $filePattern -and $_.CommandLine -match '(?i)(?:^|\s)-Mode\s+"?Watch"?(?=\s|$)' -and $_.ProcessId -ne $PID
        })
    } catch { return @() }
}

function Test-OwnedScheduledTask {
    param([object]$Task)
    if ($null -eq $Task -or @($Task.Actions).Count -ne 1) { return $false }
    $action=@($Task.Actions)[0]
    $executable=[IO.Path]::GetFileName([string]$action.Execute)
    return ($executable -ieq 'wscript.exe' -and ([string]$action.Arguments).Trim() -ceq ('"'+$script:HiddenWatchLauncherPath+'"'))
}

function Get-OwnedScheduledTask {
    param([string]$TaskName)
    $task=Get-ScheduledTask -TaskPath '\' -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -ceq $TaskName } | Select-Object -First 1
    if (Test-OwnedScheduledTask $task) { return $task }
    return $null
}

function Test-AllDriveMapsOnline {
    param([switch]$Fast)
    $allOnline = $true
    $offlineDrives = New-Object System.Collections.Generic.List[string]
    $seen = New-Object System.Collections.Generic.List[string]
    foreach ($pair in Get-Pairs) {
        try {
            $root = [System.IO.Path]::GetPathRoot((Resolve-DestinationPath $pair.Dest))
            if ([string]::IsNullOrWhiteSpace($root)) { continue }
            if ($seen.Contains($root)) { continue }
            $seen.Add($root) | Out-Null
            $isOnline = if ($Fast) { Test-DestRootAvailableFast $pair.Dest } else { Test-Path -LiteralPath $root -ErrorAction SilentlyContinue }
            if (-not $isOnline) {
                $allOnline = $false
                $offlineDrives.Add($root.TrimEnd('\')) | Out-Null
            }
        } catch {}
    }
    return [pscustomobject]@{ Online = $allOnline; OfflineDrives = @($offlineDrives.ToArray()) }
}

function Show-MainMenu {
    while ($true) {
        $pendingSnapshot = $null
        $snapshotError = $null
        try {
            $pendingSnapshot = Sync-PendingSessionSnapshot -RefreshDestinations -ShowProgress -ReadOnly
        } catch {
            $snapshotError = $_
        }
        if ($null -eq $pendingSnapshot) {
            Show-Header "Pending Status Error" "The destination status could not be prepared"
            $errorMessage = if ($null -ne $snapshotError) { [string]$snapshotError.Exception.Message } else { "Snapshot returned no result." }
            Write-Color ("Unable to check pending destinations: " + $errorMessage) "Red"
            Write-Color "No drive was marked offline. The pending queue was left unchanged." "Yellow"
            Write-Log "ERROR" ("Pending destination snapshot failed: " + $errorMessage)
            Wait-Back
            if ($script:SuppressPause) { return }
            continue
        }
        Show-Header
        Write-Color ("Config: " + $script:ConfigPath) "DarkGray"
        $menuStatusSw = [Diagnostics.Stopwatch]::StartNew()
        $pairsCount = (Get-Pairs).Count
        $queueMeta = $pendingSnapshot.Counts
        $watcherCount = @(Get-WatcherProcesses).Count
        $watcherStatus = if ($watcherCount -gt 0) { "RUN" } else { "STOP" }
        $driveStatus = $pendingSnapshot.DriveStatus
        $menuStatusSw.Stop()
        if ($menuStatusSw.ElapsedMilliseconds -gt 300) {
            Write-Log "PERF" ("Menu status took {0} ms" -f $menuStatusSw.ElapsedMilliseconds)
        }
        $statusColor = if ($driveStatus.Online) { "Green" } else { "Red" }
        $pendingCount = [int]$queueMeta.EffectiveCount
        Write-Color ("Pairs: $pairsCount    Pending: $pendingCount    Watcher: $watcherStatus") $statusColor
        if ($pendingCount -gt 0) {
            Write-Color "Changes: " "DarkGray" -NoNewLine
            Write-Color ("Add " + [int]$queueMeta.AddCount) "Green" -NoNewLine
            Write-Color ("    Update " + [int]$queueMeta.UpdateCount) "Cyan" -NoNewLine
            Write-Color ("    Delete " + [int]$queueMeta.DeleteCount) "Red"
        }
        if (-not $driveStatus.Online) {
            $offlineNames = @($driveStatus.OfflineDrives | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
            $offlineText = if ($offlineNames.Count -gt 0) { $offlineNames -join ", " } else { "configured destination" }
            Write-Color ("⚠  Drive " + $offlineText + " is not available") "Yellow"
        }
        Write-Color ("-" * 56) "DarkGray"
        Write-Color "[1] " "DarkGray" -NoNewLine; Write-Color "Apply Pending" "Yellow"
        Write-Color "[2] " "DarkGray" -NoNewLine; Write-Color "Preview Pending" "Yellow"
        Write-Color "[3] " "DarkGray" -NoNewLine; Write-Color "Full Mirror" "Yellow"
        Write-Color "[4] " "DarkGray" -NoNewLine; Write-Color "Manage Paths" "Yellow"
        Write-Color "[5] " "DarkGray" -NoNewLine; Write-Color "Manage Exclusions" "Yellow"
        Write-Color "[6] " "DarkGray" -NoNewLine; Write-Color "Clear Pending Queue" "Yellow"
        Write-Color "[7] " "DarkGray" -NoNewLine; Write-Color "Settings" "Yellow"
        Write-Color "[8] " "DarkGray" -NoNewLine; Write-Color "Install / Uninstall" "Yellow"
        Write-Color "[9] " "DarkGray" -NoNewLine; Write-Color "Status" "Yellow"
        Write-Host ""
        Write-Color ("-" * 56) "DarkGray"
        Write-Color "[Esc] Exit" "DarkGray"
        Write-Host ""
        $choice = Read-KeyChoice
        if ($null -eq $choice) { return }
        switch ($choice) {
            "1" { Invoke-ApplyPending -Snapshot $pendingSnapshot }
            "2" { Show-PendingPreview -Snapshot $pendingSnapshot }
            "3" { Invoke-FullMirror }
            "4" { Manage-PathsMenu }
            "5" { Manage-ExclusionsMenu }
            "6" { Clear-PendingQueue }
            "7" { SettingsMenu }
            "8" { InstallMenu }
            "9" { Show-Status }
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Initialize-App -ReadOnly:($Mode -in @("PreviewPending","Status"))

    switch ($Mode) {
        "Menu" { Show-MainMenu }
        "Watch" { Start-Watcher }
        "PreviewPending" { $pendingSnapshot = Sync-PendingSessionSnapshot -RefreshDestinations -ShowProgress -ReadOnly; Show-PendingPreview -Snapshot $pendingSnapshot }
        "ApplyPending" { $pendingSnapshot = Sync-PendingSessionSnapshot -RefreshDestinations -ShowProgress -ReadOnly; Invoke-ApplyPending -Snapshot $pendingSnapshot }
        "FullMirror" { Invoke-FullMirror }
        "Status" { Show-Status }
        "Install" { Install-Required }
        "RemoveTask" { Remove-ScheduledWatcherOnly }
        "Uninstall" { Uninstall-Everything }
    }
}

