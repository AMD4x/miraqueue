param(
    [ValidateSet("Menu","Watch","PreviewPending","ApplyPending","FullMirror","Status","Install","RemoveTask","Uninstall")]
    [string]$Mode = "Menu",
    [switch]$NoPause
)

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

$ErrorActionPreference = "Continue"
$script:AppName = "MiraQueue Backup"
$script:DeveloperLine = "V1.0.0 - Developed by Ahmed Mustafa"
$script:ScriptPath = $PSCommandPath
if ([string]::IsNullOrWhiteSpace($script:ScriptPath)) { $script:ScriptPath = $MyInvocation.MyCommand.Path }
if ([string]::IsNullOrWhiteSpace($script:ScriptPath)) { $script:ScriptPath = Join-Path (Get-Location).Path "MiraQueue.ps1" }
$script:ScriptDir = Split-Path -Parent $script:ScriptPath
if ([string]::IsNullOrWhiteSpace($script:ScriptDir)) { $script:ScriptDir = (Get-Location).Path }

$script:ConfigPath = Join-Path $script:ScriptDir "MiraQueue.config.json"
$script:Config = $null
$script:DataDir = $null
$script:QueuePath = $null
$script:LogPath = $null
$script:ApplyLockPath = $null
$script:ClearQueueRequestPath = $null
$script:HiddenWatchLauncherPath = $null
$script:ScriptDirPointerFile = $null
$script:Pending = @{}
$script:Mutex = $null
$script:SuppressPause = [bool]$NoPause

function Expand-TextPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
    return [Environment]::ExpandEnvironmentVariables($Path)
}

function New-DefaultConfig {
    [ordered]@{
        Version = "V1.0.0"
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
        TempCleanupMinAgeMinutes = 10
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
            "*.mbtmp-*"
        )
        PairExcludeDirs = [ordered]@{}
        PairExcludeFiles = [ordered]@{}
    }
}

function Save-Config {
    try {
        Ensure-AllPairExclusionKeys
        $json = $script:Config | ConvertTo-Json -Depth 50
        Set-Content -LiteralPath $script:ConfigPath -Value $json -Encoding UTF8
        Write-Log "INFO" "Configuration saved"
        Refresh-WatcherAfterConfigChange
    } catch {
        Write-Color "Failed to save configuration: $($_.Exception.Message)" "Red"
    }
}

function Refresh-WatcherAfterConfigChange {
    try {
        $taskName = [string]$script:Config.TaskName
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
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
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($null -eq $task -or $task.State -ne "Running") { return $task }
        Start-Sleep -Milliseconds $DelayMs
    }
    return (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)
}

function Wait-ScheduledWatcherStarted {
    param(
        [string]$TaskName,
        [int]$Attempts = 25,
        [int]$DelayMs = 200
    )
    $task = $null
    for ($i = 0; $i -lt $Attempts; $i++) {
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        $watchers = @(Get-WatcherProcesses)
        if (($null -ne $task -and $task.State -eq "Running") -or $watchers.Count -gt 0) { return $task }
        Start-Sleep -Milliseconds $DelayMs
    }
    return (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)
}

function Initialize-App {
    if (!(Test-Path -LiteralPath $script:ConfigPath)) {
        $script:Config = New-DefaultConfig
        $json = $script:Config | ConvertTo-Json -Depth 50
        Set-Content -LiteralPath $script:ConfigPath -Value $json -Encoding UTF8
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
    New-Item -ItemType Directory -Path $script:DataDir -Force | Out-Null
    $script:QueuePath = Join-Path $script:DataDir ([string]$script:Config.QueueFile)
    $script:LogPath = Join-Path $script:DataDir ([string]$script:Config.LogFile)
    $script:ApplyLockPath = Join-Path $script:DataDir "MiraQueue.apply.lock"
    $script:ClearQueueRequestPath = Join-Path $script:DataDir "MiraQueue.clear-queue"
    $script:HiddenWatchLauncherPath = Join-Path $script:DataDir "MiraQueue.watch.hidden.vbs"
    $script:ScriptDirPointerFile = Join-Path $script:DataDir "MiraQueue.scriptdir.txt"
    try {
        $existing = Get-Content -LiteralPath $script:ScriptDirPointerFile -Raw -Encoding ASCII -ErrorAction SilentlyContinue
        if (([string]::IsNullOrWhiteSpace($existing)) -or $existing.Trim() -ne $script:ScriptDir) {
            Set-Content -LiteralPath $script:ScriptDirPointerFile -Value $script:ScriptDir -Encoding ASCII
        }
    } catch {
        Set-Content -LiteralPath $script:ScriptDirPointerFile -Value $script:ScriptDir -Encoding ASCII
    }
    if (!(Test-Path -LiteralPath $script:QueuePath)) {
        New-Item -ItemType File -Path $script:QueuePath -Force | Out-Null
    }
    Rotate-LogIfNeeded
}

function Ensure-ConfigShape {
    $defaults = New-DefaultConfig
    foreach ($prop in $defaults.Keys) {
        if ($null -eq $script:Config.PSObject.Properties[$prop]) {
            $script:Config | Add-Member -NotePropertyName $prop -NotePropertyValue $defaults[$prop] -Force
        }
    }
    if ($null -eq $script:Config.Pairs) { $script:Config.Pairs = @() }
    if ($null -eq $script:Config.DriveMaps) { $script:Config.DriveMaps = [pscustomobject]@{} }
    if ($null -eq $script:Config.PairExcludeDirs) { $script:Config.PairExcludeDirs = [pscustomobject]@{} }
    if ($null -eq $script:Config.PairExcludeFiles) { $script:Config.PairExcludeFiles = [pscustomobject]@{} }
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
        $days = [int]$script:Config.LogRetentionDays
        if ($days -gt 0 -and (Test-Path -LiteralPath $script:DataDir)) {
            Get-ChildItem -LiteralPath $script:DataDir -Filter "*.old" -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$days) } |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path -LiteralPath $script:LogPath) {
            $fi = Get-Item -LiteralPath $script:LogPath -ErrorAction SilentlyContinue
            if ($fi -and $fi.Length -gt 4194304) {
                $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
                Move-Item -LiteralPath $script:LogPath -Destination "$script:LogPath.$stamp.old" -Force
            }
        }
    } catch {}
}

function Clear-Screen {
    Clear-Host
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
    $units = @("B", "KB", "MB", "GB", "TB")
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
    $cols = [ordered]@{ No=3; Status=7; Pair=12; Item=16; Progress=23; Size=17; Speed=10; Eta=7 }
    if ($width -ge 146) {
        $cols = [ordered]@{ No=3; Status=8; Pair=16; Item=30; Progress=30; Size=17; Speed=10; Eta=7 }
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
    return [pscustomobject]@{ Columns = $cols; LineWidth = $lineWidth }
}

function Get-ApplyEntryTotalBytes {
    param([object]$Entry)
    if ($null -eq $Entry -or [bool]$Entry.IsDirectory -or $Entry.Action -eq "Delete") { return [int64]0 }
    try {
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
            "WAIT" { return [pscustomobject]@{ Speed = "--"; Eta = "Waiting" } }
            "FAILED" { return [pscustomobject]@{ Speed = "--"; Eta = "Failed" } }
            "SKIPPED" { return [pscustomobject]@{ Speed = "--"; Eta = "Skipped" } }
            default { return [pscustomobject]@{ Speed = "--"; Eta = "Done" } }
        }
    }
    $elapsed = ((Get-Date) - $Row.StartedAt).TotalSeconds
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
        if ($status -eq "WAIT") { return "DarkGray" }
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
    $current = if ($Table.CurrentIndex -ge 0) { [math]::Min($total, [int]$Table.CurrentIndex + 1) } else { 0 }
    return ("Current: {0}/{1}    Done: {2}    Copying: {3}    Waiting: {4}    Skipped: {5}    Failed: {6}" -f $current, $total, $done, $copying, $waiting, $skipped, $failed)
}

function Get-ApplyProgressQueuedStatus {
    param([object]$Entry)
    if ($Entry.Action -eq "Delete") { return "DELETE" }
    if ([bool]$Entry.IsDirectory) { return "MKDIR" }
    return "WAIT"
}

function Test-ApplyProgressEntryVisible {
    param([object]$Entry, [hashtable]$VisibleEntryKeys = $null)
    if ($null -eq $VisibleEntryKeys) { return $true }
    if ($null -eq $Entry) { return $false }
    return $VisibleEntryKeys.ContainsKey((Get-QueueEntryKey $Entry))
}

function New-ApplyProgressRow {
    param([object]$Entry, [int]$No)
    return [pscustomobject]@{
        No = $No
        Status = Get-ApplyProgressQueuedStatus $Entry
        Pair = [string]$Entry.PairName
        Item = [string]$Entry.RelPath
        CopiedBytes = [int64]0
        TotalBytes = Get-ApplyEntryTotalBytes $Entry
        IsFileEntry = (-not [bool]$Entry.IsDirectory -and $Entry.Action -ne "Delete")
        ShowsSize = (-not [bool]$Entry.IsDirectory -and $Entry.Action -ne "Delete" -and $Entry.Size -ne $null)
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
    $start = $CurrentIndex - 2
    if ($start -lt 0) { $start = 0 }
    $maxStart = $total - $count
    if ($start -gt $maxStart) { $start = $maxStart }
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
    try {
        $rootFull = [System.IO.Path]::GetFullPath($Root)
        $pathFull = [System.IO.Path]::GetFullPath($Path)
        if (-not $rootFull.EndsWith("\")) { $rootFull += "\" }
        if ($pathFull.Length -lt $rootFull.Length) { return "" }
        return $pathFull.Substring($rootFull.Length).TrimStart('\')
    } catch {
        return ""
    }
}

function Join-PathSafe {
    param([string]$Base, [string]$Rel)
    if ([string]::IsNullOrWhiteSpace($Rel) -or $Rel -eq ".") { return $Base }
    try { return Join-Path $Base $Rel -ErrorAction Stop } catch { return [System.IO.Path]::Combine($Base, $Rel) }
}

function Test-NameMatchesAny {
    param([string]$Text, [object[]]$Patterns)
    foreach ($pat in $Patterns) {
        if ([string]::IsNullOrWhiteSpace([string]$pat)) { continue }
        if ($Text -like [string]$pat) { return $true }
    }
    return $false
}

function Test-Excluded {
    param([object]$Pair, [string]$FullPath, [Nullable[bool]]$IsDirectory = $null)
    $rel = Get-RelativePath $Pair.Source $FullPath
    if ([string]::IsNullOrWhiteSpace($rel)) { return $false }
    $relNorm = $rel -replace '/', '\'
    $segments = @($relNorm -split '\\' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $dirPatterns = @()
    $dirPatterns += @(Get-Array $script:Config.GlobalExcludeDirs)
    $dirPatterns += @(Get-MapArray "PairExcludeDirs" $Pair.Name)
    foreach ($seg in $segments) {
        if (Test-NameMatchesAny $seg $dirPatterns) { return $true }
    }
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

function Find-PairByName {
    param([string]$Name)
    foreach ($pair in Get-Pairs) {
        if ([string]$pair.Name -ieq [string]$Name) { return $pair }
    }
    return $null
}

function New-QueueEntry {
    param([object]$Pair, [string]$FullPath, [string]$Action, [Nullable[bool]]$KnownIsDirectory = $null)
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
    [pscustomobject]@{
        Id = [guid]::NewGuid().ToString()
        TimeUtc = (Get-Date).ToUniversalTime().ToString("o")
        PairName = [string]$Pair.Name
        Action = [string]$Action
        RelPath = [string]$rel
        Source = [string]$FullPath
        Dest = [string](Join-PathSafe (Resolve-DestinationPath $Pair.Dest) $rel)
        IsDirectory = [bool]$isDir
        Size = $size
        LastWriteTimeUtc = $lastWrite
    }
}

function Append-QueueEntry {
    param([object]$Entry)
    if ($null -eq $Entry) { return }
    try {
        $json = $Entry | ConvertTo-Json -Depth 10 -Compress
        Add-Content -LiteralPath $script:QueuePath -Value $json -Encoding UTF8
        Write-Log "QUEUE" ("{0} {1} :: {2}" -f $Entry.Action, $Entry.PairName, $Entry.RelPath)
    } catch {
        Write-Log "ERROR" "Append queue failed: $($_.Exception.Message)"
    }
}

function Read-QueueEntries {
    if (!(Test-Path -LiteralPath $script:QueuePath)) { return @() }
    $items = New-Object System.Collections.Generic.List[object]
    try {
        Get-Content -LiteralPath $script:QueuePath -Encoding UTF8 -ErrorAction SilentlyContinue | ForEach-Object {
            if ([string]::IsNullOrWhiteSpace([string]$_)) { return }
            try { $items.Add(($_ | ConvertFrom-Json)) } catch { Write-Log "WARN" "Skipped malformed queue line" }
        }
    } catch {}
    return @($items.ToArray())
}

function Get-LatestQueueEntries {
    param([object[]]$Entries)
    $dict = @{}
    foreach ($e in $Entries) {
        if ($null -eq $e.PairName -or $null -eq $e.RelPath) { continue }
        $key = ($e.PairName + "|" + $e.RelPath).ToUpperInvariant()
        $dict[$key] = $e
    }
    return @($dict.Values | Sort-Object PairName, RelPath)
}

function Remove-OrphanedUpserts {
    param([object[]]$Entries)
    $deleteKeys = @{}
    foreach ($e in $Entries) {
        if ($e.Action -eq "Delete") {
            $key = ($e.PairName + "|" + $e.RelPath).ToUpperInvariant()
            $deleteKeys[$key] = $true
        }
    }
    return @($Entries | Where-Object {
        if ($_.Action -ne "Upsert") { return $true }
        $rel = [string]$_.RelPath
        $parts = $rel.Split('\')
        for ($i = 0; $i -lt $parts.Count; $i++) {
            $parentRel = ($parts[0..$i] -join '\')
            $parentKey = ($_.PairName + "|" + $parentRel).ToUpperInvariant()
            if ($deleteKeys.ContainsKey($parentKey)) { return $false }
        }
        return $true
    })
}

function Write-QueueEntries {
    param([object[]]$Entries)
    try {
        $tmp = "$script:QueuePath.tmp"
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
        New-Item -ItemType File -Path $tmp -Force | Out-Null
        foreach ($e in $Entries) {
            Add-Content -LiteralPath $tmp -Value ($e | ConvertTo-Json -Depth 10 -Compress) -Encoding UTF8
        }
        Move-Item -LiteralPath $tmp -Destination $script:QueuePath -Force -ErrorAction Stop
    } catch {
        Write-Log "ERROR" "Rewrite queue failed: $($_.Exception.Message)"
    }
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
    Write-Color "Pending queue cleared from disk and watcher memory." "Green"
    Wait-Back
}

function Request-ClearPendingQueue {
    try {
        Set-Content -LiteralPath $script:ClearQueueRequestPath -Value (Get-Date).ToString("s") -Encoding UTF8
    } catch {}
    try {
        $script:Pending.Clear()
    } catch {}
    Write-QueueEntries @()

    $deadline = (Get-Date).AddSeconds(5)
    do {
        Start-Sleep -Milliseconds 250
        Write-QueueEntries @()
        $entries = @(Read-QueueEntries)
        if ($entries.Count -eq 0) { break }
    } while ((Get-Date) -lt $deadline)
}

function Add-PendingEvent {
    param([object]$Entry)
    if ($null -eq $Entry) { return }
    $key = Get-QueueEntryKey $Entry
    $script:Pending[$key] = [pscustomobject]@{ Entry = $Entry; Due = (Get-Date).AddMilliseconds([int]$script:Config.DebounceMs) }
}

function Normalize-QueueRelPath {
    param([string]$RelPath)
    return (([string]$RelPath) -replace '/', '\').Trim('\')
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

function Test-QueueEntryCoveredByAppliedDelete {
    param([object]$Entry, [object[]]$AppliedDeletes)
    foreach ($delete in @($AppliedDeletes)) {
        if (Test-QueueEntryChildOf -Entry $Entry -Parent $delete) { return $true }
    }
    return $false
}

function Flush-PendingEvents {
    $now = Get-Date
    foreach ($key in @($script:Pending.Keys)) {
        $item = $script:Pending[$key]
        if ($item.Due -le $now) {
            Append-QueueEntry $item.Entry
            $script:Pending.Remove($key)
        }
    }
}

function Process-ClearQueueRequest {
    if (!(Test-Path -LiteralPath $script:ClearQueueRequestPath)) { return }
    try {
        Remove-Item -LiteralPath $script:ClearQueueRequestPath -Force -ErrorAction SilentlyContinue
    } catch {}
    try {
        $script:Pending.Clear()
    } catch {}
    Write-QueueEntries @()
    Write-Log "INFO" "Pending queue cleared by request"
}

function Queue-DirectorySnapshot {
    param([object]$Entry)
    if (-not [bool]$Entry.IsDirectory) { return }
    $pair = Find-PairByName $Entry.PairName
    if ($null -eq $pair) { return }
    if (!(Test-Path -LiteralPath $Entry.Source -PathType Container)) { return }
    $count = 0
    try {
        Get-ChildItem -LiteralPath $Entry.Source -Force -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First ([int]$script:Config.DirectoryScanMaxItems) |
            ForEach-Object {
                if (Test-Excluded -Pair $pair -FullPath $_.FullName -IsDirectory $_.PSIsContainer) { return }
                $qe = New-QueueEntry -Pair $pair -FullPath $_.FullName -Action "Upsert" -KnownIsDirectory ([bool]$_.PSIsContainer)
                Append-QueueEntry $qe
                $count++
            }
        Write-Log "SCAN" "Queued directory snapshot for $($Entry.PairName) :: $($Entry.RelPath) :: $count items"
    } catch {
        Write-Log "ERROR" "Directory snapshot failed: $($_.Exception.Message)"
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

    $mutexName = "Global\MiraQueue_" + ([Math]::Abs($script:ScriptPath.ToLowerInvariant().GetHashCode()))
    $script:Mutex = New-Object System.Threading.Mutex($false, $mutexName)
    if (-not $script:Mutex.WaitOne(0, $false)) {
        Write-Color "Another watcher instance is already running." "Red"
        Wait-Back
        return
    }

    Write-Color "Watching configured sources. Changes are stored until you apply them." "DarkGray"
    Write-Color "Press Ctrl+C to stop." "DarkGray"
    Write-Host ""

    $watchers = New-Object System.Collections.Generic.List[object]
    $subscriptions = New-Object System.Collections.Generic.List[object]
    try {
        for ($i = 0; $i -lt $pairs.Count; $i++) {
            $pair = $pairs[$i]
            if (!(Test-Path -LiteralPath $pair.Source -PathType Container)) {
                Write-Color ("Missing source, skipped: " + $pair.Source) "DarkYellow"
                Write-Log "WARN" "Missing source skipped: $($pair.Name)"
                continue
            }
            $fsw = New-Object System.IO.FileSystemWatcher
            $fsw.Path = $pair.Source
            $fsw.IncludeSubdirectories = $true
            $fsw.InternalBufferSize = [Math]::Max(4096, [int]$script:Config.WatchBufferKB * 1024)
            $fsw.NotifyFilter = [System.IO.NotifyFilters]'FileName, DirectoryName, LastWrite, Size, CreationTime'
            foreach ($ev in @("Created","Changed","Deleted","Renamed")) {
                $srcId = "MBP|$i|$ev"
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
            Process-ClearQueueRequest
            Flush-PendingEvents
        }
    } finally {
        foreach ($s in $subscriptions) { Unregister-Event -SubscriptionId $s.Id -ErrorAction SilentlyContinue }
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
        $path = $args.FullPath
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
                    Add-PendingEvent (New-QueueEntry -Pair $pair -FullPath $oldPath -Action "Delete" -KnownIsDirectory ([bool]$renamedIsDir))
                } else {
                    Add-PendingEvent (New-QueueEntry -Pair $pair -FullPath $oldPath -Action "Delete")
                }
            }
            if (-not $newPathExcluded) {
                if ($renamedIsDir -ne $null) {
                    $entry = New-QueueEntry -Pair $pair -FullPath $path -Action "Upsert" -KnownIsDirectory ([bool]$renamedIsDir)
                } else {
                    $entry = New-QueueEntry -Pair $pair -FullPath $path -Action "Upsert"
                }
                Add-PendingEvent $entry
                if ($pathOk) {
                    if ([bool]$renamedIsDir) {
                        Write-Log "SCAN" ("Renamed dir: $path")
                        $scanEntry = New-QueueEntry -Pair $pair -FullPath $path -Action "Upsert" -KnownIsDirectory $true
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
            Add-PendingEvent (New-QueueEntry -Pair $pair -FullPath $path -Action "Delete")
        } elseif ($eventName -eq "Created") {
            if (!(Test-Path -LiteralPath $path)) { return }
            $isDir = Test-Path -LiteralPath $path -PathType Container
            $entry = New-QueueEntry -Pair $pair -FullPath $path -Action "Upsert" -KnownIsDirectory $isDir
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
                    $scanEntry = New-QueueEntry -Pair $pair -FullPath $path -Action "Upsert" -KnownIsDirectory $true
                    Queue-DirectorySnapshot $scanEntry
                } else {
                    Write-Log "WARN" ("Created dir not available for snapshot: $path")
                }
            }
        } else {
            if (!(Test-Path -LiteralPath $path)) { return }
            $isDir = Test-Path -LiteralPath $path -PathType Container
            Add-PendingEvent (New-QueueEntry -Pair $pair -FullPath $path -Action "Upsert" -KnownIsDirectory $isDir)
        }
    } catch {
        Write-Log "ERROR" "Process event failed: $($_.Exception.Message)"
    }
}

function Test-FileNeedsCopy {
    param([string]$Source, [string]$Dest)
    if (!(Test-Path -LiteralPath $Dest)) { return $true }
    try {
        $s = Get-Item -LiteralPath $Source -Force
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
        [scriptblock]$ProgressCallback = $null
    )
    $sourceItem = Get-Item -LiteralPath $Source -Force -ErrorAction Stop
    $total = [int64]$sourceItem.Length
    $copied = [int64]0
    if ($ProgressCallback) { & $ProgressCallback $copied $total }

    $bufferSize = 1024 * 1024
    $buffer = New-Object byte[] $bufferSize
    $inputStream = $null
    $outputStream = $null
    try {
        $inputStream = [System.IO.File]::Open($Source, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
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
}

function Copy-FileSafe {
    param(
        [string]$Source,
        [string]$Dest,
        [scriptblock]$ProgressCallback = $null
    )
    $destDir = Split-Path -Parent $Dest
    if (!(Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    if ([bool]$script:Config.CopyTempThenReplace) {
        $name = Split-Path -Leaf $Dest
        $tmp = Join-Path $destDir (".$name.mbtmp-$([guid]::NewGuid().ToString('N'))")
        try {
            Copy-FileStreamWithProgress -Source $Source -Destination $tmp -ProgressCallback $ProgressCallback
            if ([bool]$script:Config.PreserveModifiedTime) {
                try { (Get-Item -LiteralPath $tmp -Force).LastWriteTimeUtc = (Get-Item -LiteralPath $Source -Force).LastWriteTimeUtc } catch {}
            }
            if (Test-Path -LiteralPath $Dest) { Remove-Item -LiteralPath $Dest -Force -ErrorAction Stop }
            Move-Item -LiteralPath $tmp -Destination $Dest -Force
        } finally {
            if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
        }
    } else {
        Copy-FileStreamWithProgress -Source $Source -Destination $Dest -ProgressCallback $ProgressCallback
        if ([bool]$script:Config.PreserveModifiedTime) {
            try { (Get-Item -LiteralPath $Dest -Force).LastWriteTimeUtc = (Get-Item -LiteralPath $Source -Force).LastWriteTimeUtc } catch {}
        }
    }
    if ([bool]$script:Config.CopyAttributes) {
        try { (Get-Item -LiteralPath $Dest -Force).Attributes = (Get-Item -LiteralPath $Source -Force).Attributes } catch {}
    }
}

function Apply-OneEntry {
    param(
        [object]$Entry,
        [scriptblock]$ProgressCallback = $null
    )
    $pair = Find-PairByName $Entry.PairName
    if ($null -eq $pair) { return [pscustomobject]@{ Pair=$Entry.PairName; Action=$Entry.Action; Path=$Entry.RelPath; Status="FAILED"; Message="Pair not found" } }
    if (-not (Test-DestRootAvailable $pair.Dest)) { return [pscustomobject]@{ Pair=$pair.Name; Action="SKIP"; Path=$Entry.RelPath; Status="SKIPPED"; Message="Destination drive offline" } }
    $srcRoot = $pair.Source
    $dstRoot = Resolve-DestinationPath $pair.Dest
    $source = Join-PathSafe $srcRoot $Entry.RelPath
    $dest = Join-PathSafe $dstRoot $Entry.RelPath
    try {
        if ($Entry.Action -eq "Delete") {
            if (-not [bool]$script:Config.DeleteDestOnSourceDelete) {
                return [pscustomobject]@{ Pair=$pair.Name; Action="DELETE"; Path=$Entry.RelPath; Status="SKIPPED"; Message="Delete disabled" }
            }
            if (Test-Path -LiteralPath $dest) {
                Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction Stop
                return [pscustomobject]@{ Pair=$pair.Name; Action="DELETE"; Path=$Entry.RelPath; Status="OK"; Message="" }
            }
            return [pscustomobject]@{ Pair=$pair.Name; Action="DELETE"; Path=$Entry.RelPath; Status="SKIPPED"; Message="Destination missing" }
        }
        if (!(Test-Path -LiteralPath $source)) {
            return [pscustomobject]@{ Pair=$pair.Name; Action="COPY"; Path=$Entry.RelPath; Status="FAILED"; Message="Source missing" }
        }
        if ($Entry.IsDirectory) {
            if (Test-Path -LiteralPath $dest -PathType Container) {
                return [pscustomobject]@{ Pair=$pair.Name; Action="MKDIR"; Path=$Entry.RelPath; Status="SKIPPED"; Message="Directory exists" }
            }
            New-Item -ItemType Directory -Path $dest -Force | Out-Null
            return [pscustomobject]@{ Pair=$pair.Name; Action="MKDIR"; Path=$Entry.RelPath; Status="OK"; Message="" }
        }
        if (Test-FileNeedsCopy -Source $source -Dest $dest) {
            Copy-FileSafe -Source $source -Dest $dest -ProgressCallback $ProgressCallback
            return [pscustomobject]@{ Pair=$pair.Name; Action="COPY"; Path=$Entry.RelPath; Status="OK"; Message="" }
        }
        return [pscustomobject]@{ Pair=$pair.Name; Action="COPY"; Path=$Entry.RelPath; Status="SKIPPED"; Message="Already current" }
    } catch {
        return [pscustomobject]@{ Pair=$pair.Name; Action=$Entry.Action.ToUpperInvariant(); Path=$Entry.RelPath; Status="FAILED"; Message=$(Format-ErrorSummary $_.Exception.Message) }
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

function Test-ApplyResultSelectedForDisplay {
    param([object]$Entry, [object]$Result, [hashtable]$VisibleEntryKeys = $null)
    if ($null -eq $Result) { return $true }
    if ($Result.Status -eq "FAILED") { return $true }
    if ($null -ne $VisibleEntryKeys -and $null -ne $Entry -and $VisibleEntryKeys.ContainsKey((Get-QueueEntryKey $Entry))) { return $true }
    if ($Result.Status -eq "SKIPPED" -and ($Result.Message -eq "Destination drive offline" -or $Result.Message -eq "Delete disabled")) { return $true }
    return $false
}

function Invoke-ApplyPending {
    param([switch]$Quiet)
    $entries = @(Read-QueueEntries)
    $latest = @(Get-LatestQueueEntries $entries)
    $latest = @(Remove-OrphanedUpserts $latest)
    if ($latest.Count -eq 0) {
        if (-not $Quiet) {
            Show-Header "Apply Pending" "No queued changes"
            Write-Color "Queue is empty." "Green"
            Wait-Back
        }
        return
    }
    Show-Header "Apply Pending" "Recorded source changes only"
    $results = New-Object System.Collections.Generic.List[object]
    $displayResults = New-Object System.Collections.Generic.List[object]
    $visibleResultKeys = @{}
    foreach ($visibleEntry in @(Get-VisiblePendingEntries $latest)) {
        $visibleResultKeys[(Get-QueueEntryKey $visibleEntry)] = $true
    }
    $okKeys = New-Object System.Collections.Generic.List[string]
    $appliedDeletes = New-Object System.Collections.Generic.List[object]
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

        $progressTable = New-ApplyProgressTable -Entries $latest -VisibleEntryKeys $visibleResultKeys
        for ($i = 0; $i -lt $latest.Count; $i++) {
            $entry = $latest[$i]
            $rowIndex = $i
            $startedAt = Get-Date
            $startStatus = Get-ApplyProgressStartingStatus $entry
            Update-ApplyProgressRow -Table $progressTable -Index $rowIndex -Status $startStatus -StartedAt $startedAt -ForceRender
            $progressCallback = {
                param([int64]$CopiedBytes, [int64]$TotalBytes)
                Update-ApplyProgressRow -Table $progressTable -Index $rowIndex -Status "COPYING" -CopiedBytes $CopiedBytes -TotalBytes $TotalBytes -StartedAt $startedAt
            }
            $r = Apply-OneEntry -Entry $entry -ProgressCallback $progressCallback
            $finalStatus = Get-ApplyProgressFinalStatus $r
            $finalTotal = Get-ApplyEntryTotalBytes $entry
            $finalCopied = if (($finalStatus -eq "DONE" -or ($finalStatus -eq "SKIPPED" -and $r.Message -eq "Already current")) -and $finalTotal -gt 0) { $finalTotal } else { [int64]0 }
            if ($finalStatus -eq "DONE") {
                try {
                    $pair = Find-PairByName $entry.PairName
                    if ($null -ne $pair) {
                        $dstRoot = Resolve-DestinationPath $pair.Dest
                        $destPath = Join-PathSafe $dstRoot $entry.RelPath
                        if (Test-Path -LiteralPath $destPath -PathType Leaf) {
                            $finalTotal = [int64](Get-Item -LiteralPath $destPath -Force).Length
                            $finalCopied = $finalTotal
                        }
                    }
                } catch {}
            }
            $showInDisplay = Test-ApplyResultSelectedForDisplay -Entry $entry -Result $r -VisibleEntryKeys $visibleResultKeys
            Update-ApplyProgressRow -Table $progressTable -Index $rowIndex -Status $finalStatus -CopiedBytes $finalCopied -TotalBytes $finalTotal -Complete -ForceRender -ShowIfHidden:$showInDisplay
            $results.Add($r) | Out-Null
            if ($showInDisplay) {
                $displayResults.Add($r) | Out-Null
            }
            if ($r.Status -ne "FAILED" -and $r.Message -ne "Destination drive offline") {
                $okKeys.Add((Get-QueueEntryKey $entry))
                if ($entry.Action -eq "Delete" -and ($r.Status -eq "OK" -or ($r.Status -eq "SKIPPED" -and $r.Message -eq "Destination missing"))) {
                    $appliedDeletes.Add($entry) | Out-Null
                }
            }
        }
        $remaining = @($entries | Where-Object {
            $key = Get-QueueEntryKey $_
            -not $okKeys.Contains($key) -and -not (Test-QueueEntryCoveredByAppliedDelete -Entry $_ -AppliedDeletes @($appliedDeletes.ToArray()))
        })
        $knownIds = @($entries | ForEach-Object { $_.Id })
        $currentOnDisk = @(Read-QueueEntries)
        $newFromWatcher = @($currentOnDisk | Where-Object { $knownIds -notcontains $_.Id })
        Write-QueueEntries ($remaining + $newFromWatcher)
    } finally {
        if ($cursorChanged) {
            try { [Console]::CursorVisible = $previousCursorVisible } catch {}
        }
    }
    Show-ApplyResults -Results @($displayResults.ToArray()) -Title "Apply Results" -Compact
}

function Show-PendingPreview {
    $entries = @(Read-QueueEntries)
    $latest = @(Get-LatestQueueEntries $entries)
    $latest = @(Remove-OrphanedUpserts $latest)
    Show-Header "Preview Pending" "Enter = apply   Esc = back"
    if ($latest.Count -eq 0) {
        Write-Color "No pending changes found." "Green"
        Wait-Back
        return
    }
    $visible = @(Get-VisiblePendingEntries $latest)
    if ($visible.Count -eq 0) {
        Write-Color "No destination changes were needed." "Green"
        Write-Color "Applying will clear these already-satisfied records from the queue." "DarkGray"
        Write-Host ""
        $ok = Read-EnterOrEsc "Clear these recorded no-op changes now?"
        if ($ok) { Invoke-ApplyPending }
        return
    }
    Write-PendingTable $visible
    Write-Host ""
    $allOffline = (@($visible | Where-Object { (Get-DisplayAction $_) -ne "OFFLINE" }).Count -eq 0)
    if ($allOffline) {
        Write-Color "All pending entries are offline. Destination drive is not available." "Yellow"
        Wait-Back
        return
    }
    $ok = Read-EnterOrEsc "Apply these recorded changes now?"
    if ($ok) { Invoke-ApplyPending }
}

function Get-DisplayAction {
    param([object]$Entry)
    if ($Entry.Action -eq "Delete") { return "DELETE" }
    $pair = Find-PairByName $Entry.PairName
    if ($null -eq $pair) { return "NEW" }
    if (-not (Test-DestRootAvailable $pair.Dest)) { return "OFFLINE" }
    $dest = Resolve-DestinationPath (Join-PathSafe $pair.Dest $Entry.RelPath)
    if ([string]::IsNullOrWhiteSpace($dest)) { return "N/A" }
    if (Test-Path -LiteralPath $dest -ErrorAction SilentlyContinue) { return "UPDATE" }
    return "NEW"
}

function Test-PendingPreviewEntryVisible {
    param([object]$Entry)
    if ($null -eq $Entry) { return $false }
    if ($Entry.Action -eq "Delete") {
        $dest = Get-QueueEntryDestinationPath $Entry
        if (-not [string]::IsNullOrWhiteSpace($dest) -and -not (Test-Path -LiteralPath $dest -ErrorAction SilentlyContinue)) { return $false }
    }
    $action = Get-DisplayAction $Entry
    if ($action -eq "OFFLINE" -or $action -eq "N/A") { return $true }
    if ([bool]$Entry.IsDirectory -and $action -eq "UPDATE") { return $false }
    return $true
}

function Get-QueueEntryDestinationPath {
    param([object]$Entry)
    if ($null -eq $Entry) { return $null }
    $pair = Find-PairByName $Entry.PairName
    if ($null -ne $pair) {
        $p = Join-PathSafe $pair.Dest $Entry.RelPath
        if (-not [string]::IsNullOrWhiteSpace($p)) { return (Resolve-DestinationPath $p) }
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$Entry.Dest)) { return [string]$Entry.Dest }
    return $null
}

function Get-VisiblePendingEntries {
    param([object[]]$Entries)
    return @($Entries | Where-Object { Test-PendingPreviewEntryVisible $_ })
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
    param([object[]]$Items)
    $wPair = 22; $wAction = 8; $wKind = 6; $wPath = 48
    $line = "+" + ("-"*8) + "+" + ("-"*($wPair+2)) + "+" + ("-"*($wAction+2)) + "+" + ("-"*($wKind+2)) + "+" + ("-"*($wPath+2)) + "+"
    Write-Color $line "DarkGray"
    Write-Color ("| {0} | {1} | {2} | {3} | {4} |" -f (Center-Text "No." 6),(Center-Text "Pair" $wPair),(Center-Text "Action" $wAction),(Center-Text "Kind" $wKind),(Center-Text "Path" $wPath)) "DarkGray"
    Write-Color $line "DarkGray"
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $e = $Items[$i]
        $kind = if ($e.IsDirectory) { "DIR" } else { "FILE" }
        $action = Get-DisplayAction $e
        $color = if ($action -eq "DELETE") { "Red" } elseif ($action -eq "NEW") { "Green" } elseif ($action -eq "OFFLINE") { "DarkRed" } else { "Yellow" }
        Write-Color "| " "DarkGray" -NoNewLine
        Write-Color (Center-Text ("{0:00}/{1:00}" -f ($i+1), $Items.Count) 6) "DarkGray" -NoNewLine
        Write-Color " | " "DarkGray" -NoNewLine
        Write-Color (Fit-Cell $e.PairName $wPair) "Cyan" -NoNewLine
        Write-Color " | " "DarkGray" -NoNewLine
        Write-Color (Center-Text $action $wAction) $color -NoNewLine
        Write-Color " | " "DarkGray" -NoNewLine
        Write-Color (Center-Text $kind $wKind) "White" -NoNewLine
        Write-Color " | " "DarkGray" -NoNewLine
        Write-Color (Fit-Cell $e.RelPath $wPath) "White" -NoNewLine
        Write-Color " |" "DarkGray"
    }
    Write-Color $line "DarkGray"
}

function Show-ApplyResults {
    param([object[]]$Results, [string]$Title, [switch]$Compact)
    Show-Header $Title "Press any key after review"
    $visibleResults = @($Results | Where-Object { Test-ApplyResultVisible $_ })
    if ($visibleResults.Count -eq 0) {
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
    $folders = @($Results | Where-Object { $_.Action -eq "MKDIR" -and $_.Status -eq "OK" }).Count
    $deleted = @($Results | Where-Object { $_.Action -eq "DELETE" -and $_.Status -eq "OK" }).Count
    $skipped = @($Results | Where-Object { $_.Status -eq "SKIPPED" }).Count
    $failed = @($Results | Where-Object { $_.Status -eq "FAILED" }).Count
    $total = @($Results).Count

    Write-Color ("Displayed items : " + $total) "DarkGray"
    Write-Color ("Copied          : " + $copied) "Green"
    Write-Color ("Folders created : " + $folders) "Green"
    Write-Color ("Deleted         : " + $deleted) "Yellow"
    Write-Color ("Skipped         : " + $skipped) $(if ($skipped -gt 0) { "Yellow" } else { "DarkGray" })
    Write-Color ("Failed          : " + $failed) $(if ($failed -gt 0) { "Red" } else { "DarkGray" })
    Write-Host ""

    $detailResults = @($Results | Where-Object {
        if ($_.Status -eq "FAILED") { return $true }
        if ($_.Status -eq "SKIPPED" -and $_.Message -ne "Already current" -and $_.Message -ne "Directory exists" -and $_.Message -ne "Destination missing") { return $true }
        return $false
    })
    if ($detailResults.Count -eq 0) {
        if ($failed -eq 0) { Write-Color "All pending changes applied successfully." "Green" }
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

function Build-RobocopyArgs {
    param(
        [object]$Pair,
        [bool]$Preview,
        [ValidateSet("STRICT","UPDATE_KEEP_EXTRAS","MISSING_ONLY")]
        [string]$Policy
    )
    $dest = Resolve-DestinationPath $Pair.Dest
    $args = @(
        $Pair.Source,
        $dest
    )
    if ($Policy -eq "STRICT") {
        if ($Preview) {
            $args += "/E"
        } else {
            $args += "/MIR"
        }
    } elseif ($Policy -eq "UPDATE_KEEP_EXTRAS") {
        $args += "/E"
    } else {
        $args += @("/E", "/XC", "/XN", "/XO", "/XX")
    }
    $args += @(
        "/FFT",
        "/Z",
        ("/MT:{0}" -f [int]$script:Config.RobocopyThreads),
        ("/R:{0}" -f [int]$script:Config.RobocopyRetries),
        ("/W:{0}" -f [int]$script:Config.RobocopyWaitSeconds),
        "/COPY:DAT",
        "/DCOPY:DA",
        "/XJ",
        "/NP"
    )
    if ($Preview) { $args += "/L" }
    $excludeDirs = @()
    $excludeDirs += @(Get-Array $script:Config.GlobalExcludeDirs)
    $excludeDirs += @(Get-MapArray "PairExcludeDirs" $Pair.Name)
    $excludeFiles = @()
    $excludeFiles += @(Get-Array $script:Config.GlobalExcludeFiles)
    $excludeFiles += @(Get-MapArray "PairExcludeFiles" $Pair.Name)
    if ($Preview) {
        $excludeFiles = @($excludeFiles | Where-Object { [string]$_ -ine "*.mbtmp-*" })
    }
    if ($excludeDirs.Count -gt 0) { $args += "/XD"; $args += $excludeDirs }
    if ($excludeFiles.Count -gt 0) { $args += "/XF"; $args += $excludeFiles }
    return $args
}

function Decode-RobocopyExit {
    param([int]$Code)
    if ($Code -eq 0) { return "MATCHED" }
    if ($Code -ge 16) { return "ERROR" }
    if (($Code -band 8) -ne 0) { return "ERROR" }
    return "CHANGED"
}

function Get-RobocopySummary {
    param([object[]]$Output)
    $summary = [ordered]@{
        DirsTotal = 0; DirsCopied = 0; DirsSkipped = 0; DirsMismatch = 0; DirsFailed = 0; DirsExtras = 0
        FilesTotal = 0; FilesCopied = 0; FilesSkipped = 0; FilesMismatch = 0; FilesFailed = 0; FilesExtras = 0
    }

    foreach ($lineObj in @($Output)) {
        $line = [string]$lineObj
        if ($line -notmatch '^\s*(Dirs|Files)\s*:\s*(.+)$') { continue }

        $kind = $Matches[1]
        $numbers = @([regex]::Matches($Matches[2], '\d[\d,]*') | ForEach-Object {
            [int64](($_.Value) -replace ',', '')
        })
        if ($numbers.Count -lt 6) { continue }

        $prefix = if ($kind -eq "Dirs") { "Dirs" } else { "Files" }
        $summary["${prefix}Total"] = $numbers[0]
        $summary["${prefix}Copied"] = $numbers[1]
        $summary["${prefix}Skipped"] = $numbers[2]
        $summary["${prefix}Mismatch"] = $numbers[3]
        $summary["${prefix}Failed"] = $numbers[4]
        $summary["${prefix}Extras"] = $numbers[5]
    }

    return [pscustomobject]$summary
}

function Get-RobocopyChangeSummary {
    param([object[]]$Output)
    $newFiles = 0
    $updatedFiles = 0
    $extraFiles = 0
    $newDirs = 0
    $extraDirs = 0

    foreach ($lineObj in @($Output)) {
        $line = [string]$lineObj
        if ($line -match '^\s*New File') { $newFiles++; continue }
        if ($line -match '^\s*(Newer|Older|Changed)') { $updatedFiles++; continue }
        if ($line -match '^\s*\*EXTRA File') { $extraFiles++; continue }
        if ($line -match '^\s*New Dir') { $newDirs++; continue }
        if ($line -match '^\s*\*EXTRA Dir') { $extraDirs++; continue }
    }

    return [pscustomobject]@{
        NewFiles = $newFiles
        UpdatedFiles = $updatedFiles
        ExtraFiles = $extraFiles
        NewDirs = $newDirs
        ExtraDirs = $extraDirs
    }
}

function Test-RobocopyChangeLine {
    param([string]$Line)
    if ([string]::IsNullOrWhiteSpace($Line)) { return $false }
    return ($Line -match '^\s*(New File|New Dir|Newer|Older|Changed|\*EXTRA)')
}

function Get-RobocopyChangeText {
    param([string]$Line)
    $text = ([string]$Line).Trim()
    $text = [regex]::Replace($text, '\s+', ' ')

    $path = ""
    $pathMatch = [regex]::Match($text, '([A-Za-z]:\\.*|\\\\.*)$')
    if ($pathMatch.Success) { $path = $pathMatch.Groups[1].Value.Trim() }

    if ($text -match '^\*EXTRA Dir') {
        $text = "Extra folder: " + $(if ($path) { $path } else { ($text -replace '^\*EXTRA Dir\s+-?\d+\s+', '') })
    } elseif ($text -match '^\*EXTRA File') {
        $text = "Extra file: " + $(if ($path) { $path } else { ($text -replace '^\*EXTRA File\s+(.+?\s+)?', '') })
    } elseif ($text -match '^New Dir') {
        $text = "New folder: " + $(if ($path) { $path } else { ($text -replace '^New Dir\s+\d+\s+', '') })
    } elseif ($text -match '^New File') {
        $text = "New file: " + $(if ($path) { $path } else { ($text -replace '^New File\s+(.+?\s+)?', '') })
    } elseif ($text -match '^(Newer|Older|Changed)') {
        $text = "Update file: " + $(if ($path) { $path } else { ($text -replace '^(Newer|Older|Changed)\s+(.+?\s+)?', '') })
    }

    if ($text.Length -gt 92) { $text = $text.Substring(0, 92) + "..." }
    return $text
}

function Convert-RobocopyLineToChange {
    param([string]$Line, [string]$SourceRoot, [string]$DestRoot)
    $line = $Line.Trim()
    $action = $null; $type = $null; $changeAction = $null
    if ($line -match '^New\s+File\s+') { $action = "COPY"; $type = "FILE"; $changeAction = "NEW" }
    elseif ($line -match '^New\s+Dir\s+') { $action = "MKDIR"; $type = "DIR"; $changeAction = "NEW" }
    elseif ($line -match '^(Newer|Older|Changed)\s+') { $action = "COPY"; $type = "FILE"; $changeAction = "UPDATE" }
    elseif ($line -match '^\*EXTRA\s+File\s+') { $action = "DELETE"; $type = "FILE"; $changeAction = "DELETE" }
    elseif ($line -match '^\*EXTRA\s+Dir\s+') { $action = "DELETE"; $type = "DIR"; $changeAction = "DELETE" }
    else { return $null }
    $pathMatch = [regex]::Match($line, '([A-Za-z]:\\.*|\\\\.*)$')
    $root = if ($action -eq "DELETE") { $DestRoot } else { $SourceRoot }
    if ($pathMatch.Success) {
        $fullPath = $pathMatch.Groups[1].Value.TrimEnd('\')
        $relPath = Get-RelativePath $root $fullPath
        if ([string]::IsNullOrWhiteSpace($relPath) -and $fullPath.Length -gt $root.Length) {
            $relPath = $fullPath.Substring($root.Length).TrimStart('\')
        }
    } else {
        $relPath = ($line -replace '^\S+\s+\S+\s+', '').Trim()
    }
    if ([string]::IsNullOrWhiteSpace($relPath)) { return $null }
    if ($action -eq "DELETE" -and $type -eq "FILE") {
        $leaf = Split-Path -Path $relPath -Leaf
        if (Test-InternalTempCleanupFileName $leaf) {
            $tempPath = Join-PathSafe $DestRoot $relPath
            if (-not (Test-TempCleanupFileEligible -FullPath $tempPath -DestRoot $DestRoot)) { return $null }
            return [PSCustomObject]@{ Action = "CLEANUP"; Type = "FILE"; RelPath = $relPath; ChangeAction = "CLEANUP" }
        }
    }
    return [PSCustomObject]@{ Action = $action; Type = $type; RelPath = $relPath; ChangeAction = $changeAction }
}
    

function Write-ScanProgress {
    param(
        [int]$FrameIndex,
        [string]$PairName,
        [string]$Text,
        [string]$Color = "Cyan"
    )
    $frames = @("/", "-", "\", "|")
    $frame = $frames[$FrameIndex % $frames.Count]
    $line = "{0} Scanning {1}: {2}" -f $frame, $PairName, $Text
    try {
        $width = [Console]::WindowWidth
        if ($width -lt 40) { $width = 120 }
        $max = $width - 1
        if ($line.Length -gt $max) { $line = $line.Substring(0, $max) }
        Write-Host -NoNewline ("`r" + $line.PadRight($max)) -ForegroundColor $Color
    } catch {
        Write-Host $line -ForegroundColor $Color
    }
}

function ConvertTo-ProcessArgumentString {
    param([string[]]$Arguments)
    $quoted = @()
    foreach ($arg in $Arguments) {
        $text = [string]$arg
        if ($text -match '[\s"]') {
            $text = '"' + ($text -replace '"', '\"') + '"'
        }
        $quoted += $text
    }
    return ($quoted -join ' ')
}

function Clear-ScanProgress {
    try {
        $width = [Console]::WindowWidth
        if ($width -lt 40) { $width = 120 }
        Write-Host -NoNewline ("`r" + (" " * ($width - 1)) + "`r")
    } catch {
        Write-Host ""
    }
}

function Invoke-RobocopyStreaming {
    param(
        [string[]]$RobocopyArgs,
        [string]$PairName
    )
    $output = New-Object 'System.Collections.Generic.List[string]'
    $frame = 0
    $lastChange = "Reading Folders"
    $shownChanges = 0
    $maxShownChanges = 18

    $queue = [System.Collections.Queue]::Synchronized((New-Object System.Collections.Queue))
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo.FileName = "robocopy.exe"
    $proc.StartInfo.Arguments = ConvertTo-ProcessArgumentString $RobocopyArgs
    $proc.StartInfo.UseShellExecute = $false
    $proc.StartInfo.RedirectStandardOutput = $true
    $proc.StartInfo.RedirectStandardError = $true
    $proc.StartInfo.StandardOutputEncoding = [System.Text.Encoding]::GetEncoding(437)
    $proc.StartInfo.CreateNoWindow = $true
    $outSub = $null
    $errSub = $null

    try {
        $outSub = Register-ObjectEvent -InputObject $proc -EventName OutputDataReceived -MessageData $queue -Action {
            if ($null -ne $EventArgs.Data) { $Event.MessageData.Enqueue([string]$EventArgs.Data) }
        }
        $errSub = Register-ObjectEvent -InputObject $proc -EventName ErrorDataReceived -MessageData $queue -Action {
            if ($null -ne $EventArgs.Data) { $Event.MessageData.Enqueue([string]$EventArgs.Data) }
        }

        [void]$proc.Start()
        $proc.BeginOutputReadLine()
        $proc.BeginErrorReadLine()

        while (-not $proc.HasExited -or $queue.Count -gt 0) {
            $drained = $false
            while ($queue.Count -gt 0) {
                $drained = $true
                $line = [string]$queue.Dequeue()
                [void]$output.Add($line)
                if (Test-RobocopyChangeLine $line) {
                    $lastChange = Get-RobocopyChangeText $line
                    $color = if ($line -match '^\s*\*EXTRA') { "DarkYellow" } elseif ($line -match '^\s*New Dir') { "Cyan" } else { "Yellow" }
                    Write-ScanProgress -FrameIndex $frame -PairName $PairName -Text $lastChange -Color $color
                    if ($shownChanges -lt $maxShownChanges) {
                        Clear-ScanProgress
                        Write-Color ("  -> " + $lastChange) $color
                        $shownChanges++
                    }
                } else {
                    Write-ScanProgress -FrameIndex $frame -PairName $PairName -Text $lastChange -Color "Cyan"
                }
                $frame++
            }
            if (-not $drained) {
                Write-ScanProgress -FrameIndex $frame -PairName $PairName -Text $lastChange -Color "Cyan"
                $frame++
                Start-Sleep -Milliseconds 120
            }
        }
        $proc.WaitForExit()
        Start-Sleep -Milliseconds 300
        while ($queue.Count -gt 0) {
            $line = [string]$queue.Dequeue()
            [void]$output.Add($line)
        }
        $code = [int]$proc.ExitCode
    } catch {
        [void]$output.Add($_.Exception.Message)
        $code = 16
    } finally {
        if ($outSub) { Unregister-Event -SubscriptionId $outSub.Id -ErrorAction SilentlyContinue }
        if ($errSub) { Unregister-Event -SubscriptionId $errSub.Id -ErrorAction SilentlyContinue }
        if ($proc -and -not $proc.HasExited) {
            try { $proc.Kill() } catch {}
        }
        if ($proc) { try { $proc.Dispose() } catch {} }
        Clear-ScanProgress
    }

    return [pscustomobject]@{
        Output = @($output.ToArray())
        Code = $code
    }
}

function Invoke-ApplyFileChanges {
    param([object]$Pair, [object[]]$FileChanges, [string]$Policy)
    $dstRoot = Resolve-DestinationPath $Pair.Dest
    $results = New-Object System.Collections.Generic.List[object]
    $roboThreads = [int]$script:Config.RobocopyThreads
    $roboRetries = [int]$script:Config.RobocopyRetries
    $roboWait = [int]$script:Config.RobocopyWaitSeconds

    Write-Host ("  Applying changes for [{0}] ..." -f $Pair.Name) -ForegroundColor Cyan

    # MKDIR — create directories and robocopy /E on the subdirectory only
    foreach ($ch in @($FileChanges | Where-Object { $_.Action -eq "MKDIR" })) {
        $srcDir = Join-PathSafe $Pair.Source $ch.RelPath
        $dstDir = Join-PathSafe $dstRoot $ch.RelPath
        try {
            if (!(Test-Path -LiteralPath $dstDir -PathType Container)) {
                New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
            }
            $roboArgStr = ConvertTo-ProcessArgumentString @($srcDir, $dstDir, "/E", "/COPY:DAT", "/DCOPY:DA", "/XJ", "/NP",
                ("/MT:{0}" -f $roboThreads), ("/R:{0}" -f $roboRetries), ("/W:{0}" -f $roboWait))
            $roboPsi = New-Object System.Diagnostics.ProcessStartInfo
            $roboPsi.FileName = "robocopy.exe"
            $roboPsi.Arguments = $roboArgStr
            $roboPsi.UseShellExecute = $false
            $roboPsi.CreateNoWindow = $true
            $roboProc = New-Object System.Diagnostics.Process
            $roboProc.StartInfo = $roboPsi
            $roboProc.Start() | Out-Null
            $roboProc.WaitForExit()
            $roboExit = $roboProc.ExitCode
            $roboProc.Dispose()
            if ($roboExit -ge 8) {
                $results.Add([pscustomobject]@{ Pair = $Pair.Name; Action = "MKDIR"; Path = $ch.RelPath; Status = "FAILED"; Message = "Robocopy exit $roboExit" })
            } else {
                $results.Add([pscustomobject]@{ Pair = $Pair.Name; Action = "MKDIR"; Path = $ch.RelPath; Status = "OK"; Message = "Copied subtree" })
            }
        } catch {
            $results.Add([pscustomobject]@{ Pair = $Pair.Name; Action = "MKDIR"; Path = $ch.RelPath; Status = "FAILED"; Message = (Format-ErrorSummary $_.Exception.Message) })
        }
    }

    # COPY — individual files
    foreach ($ch in @($FileChanges | Where-Object { $_.Action -eq "COPY" })) {
        $srcPath = Join-PathSafe $Pair.Source $ch.RelPath
        $dstPath = Join-PathSafe $dstRoot $ch.RelPath
        try {
            if (!(Test-Path -LiteralPath $srcPath)) {
                $results.Add([pscustomobject]@{ Pair = $Pair.Name; Action = "COPY"; Path = $ch.RelPath; Status = "SKIPPED"; Message = "Source missing" }); continue
            }
            if (Test-FileNeedsCopy -Source $srcPath -Dest $dstPath) {
                Copy-FileSafe -Source $srcPath -Dest $dstPath
                $results.Add([pscustomobject]@{ Pair = $Pair.Name; Action = "COPY"; Path = $ch.RelPath; Status = "OK"; Message = "" })
            } else {
                $results.Add([pscustomobject]@{ Pair = $Pair.Name; Action = "COPY"; Path = $ch.RelPath; Status = "SKIPPED"; Message = "Already current" })
            }
        } catch {
            $results.Add([pscustomobject]@{ Pair = $Pair.Name; Action = "COPY"; Path = $ch.RelPath; Status = "FAILED"; Message = (Format-ErrorSummary $_.Exception.Message) })
        }
    }

    # DELETE — extra files and dirs
    foreach ($ch in @($FileChanges | Where-Object { $_.Action -eq "DELETE" })) {
        $dstPath = Join-PathSafe $dstRoot $ch.RelPath
        try {
            if (Test-Path -LiteralPath $dstPath) {
                if ($ch.Type -eq "DIR") { Remove-Item -LiteralPath $dstPath -Recurse -Force -ErrorAction Stop }
                else { Remove-Item -LiteralPath $dstPath -Force -ErrorAction Stop }
                $results.Add([pscustomobject]@{ Pair = $Pair.Name; Action = "DELETE"; Path = $ch.RelPath; Status = "OK"; Message = "" })
            } else {
                $results.Add([pscustomobject]@{ Pair = $Pair.Name; Action = "DELETE"; Path = $ch.RelPath; Status = "SKIPPED"; Message = "Destination missing" })
            }
        } catch {
            $results.Add([pscustomobject]@{ Pair = $Pair.Name; Action = "DELETE"; Path = $ch.RelPath; Status = "FAILED"; Message = (Format-ErrorSummary $_.Exception.Message) })
        }
    }

    return @($results.ToArray())
}

function Get-TempCleanupMinAgeMinutes {
    try {
        if ($null -ne $script:Config -and $null -ne $script:Config.PSObject.Properties["TempCleanupMinAgeMinutes"]) {
            $minutes = [int]$script:Config.TempCleanupMinAgeMinutes
            if ($minutes -ge 0) { return $minutes }
        }
    } catch {}
    return 10
}

function Test-InternalTempCleanupFileName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $false }
    return ($Name -match '^\..+\.mbtmp-[0-9a-fA-F]{32}$')
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

function Test-TempCleanupFileEligible {
    param(
        [string]$FullPath,
        [string]$DestRoot,
        [datetime]$NowUtc = (Get-Date).ToUniversalTime()
    )
    if (-not (Test-PathInsideRoot -Root $DestRoot -Path $FullPath)) { return $false }
    if (-not (Test-Path -LiteralPath $FullPath -PathType Leaf)) { return $false }
    $leaf = Split-Path -Path $FullPath -Leaf
    if (-not (Test-InternalTempCleanupFileName $leaf)) { return $false }
    try {
        $item = Get-Item -LiteralPath $FullPath -Force -ErrorAction Stop
        $age = $NowUtc - $item.LastWriteTimeUtc
        return ($age.TotalMinutes -ge (Get-TempCleanupMinAgeMinutes))
    } catch {
        return $false
    }
}

function Invoke-TempCleanupChanges {
    param([object]$Pair, [object[]]$FileChanges)
    $dstRoot = Resolve-DestinationPath $Pair.Dest
    $results = New-Object System.Collections.Generic.List[object]
    foreach ($ch in @($FileChanges | Where-Object { $_.Action -eq "CLEANUP" })) {
        $dstPath = Join-PathSafe $dstRoot $ch.RelPath
        try {
            if (-not (Test-Path -LiteralPath $dstPath -PathType Leaf)) {
                $results.Add([pscustomobject]@{ Pair = $Pair.Name; Action = "CLEANUP"; Path = $ch.RelPath; Status = "SKIPPED"; Message = "Destination missing" }) | Out-Null
                continue
            }
            if (-not (Test-TempCleanupFileEligible -FullPath $dstPath -DestRoot $dstRoot)) {
                $results.Add([pscustomobject]@{ Pair = $Pair.Name; Action = "CLEANUP"; Path = $ch.RelPath; Status = "SKIPPED"; Message = "Not old temp file" }) | Out-Null
                continue
            }
            Remove-Item -LiteralPath $dstPath -Force -ErrorAction Stop
            $results.Add([pscustomobject]@{ Pair = $Pair.Name; Action = "CLEANUP"; Path = $ch.RelPath; Status = "OK"; Message = "Removed old temp file" }) | Out-Null
        } catch {
            $results.Add([pscustomobject]@{ Pair = $Pair.Name; Action = "CLEANUP"; Path = $ch.RelPath; Status = "FAILED"; Message = (Format-ErrorSummary $_.Exception.Message) }) | Out-Null
        }
    }
    return @($results.ToArray())
}

function Invoke-FullMirror {
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
        $results = Invoke-RobocopyForPairs -Pairs $pairs -Preview:$false -Policy $policy
        Show-RobocopyResults -Results $results -Title "Full Mirror Results" -Pause:$true
        Request-ClearPendingQueue
        return
    }

    # Show preview
    Show-Header "Full Mirror Preview" (Get-PolicyLabel $policy)
    $previewResults = Invoke-RobocopyForPairs -Pairs $pairs -Preview:$true -Policy $policy

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
    $changedResults = @($previewResults | Where-Object { $_.Status -eq "CHANGED" })
    if ($changedResults.Count -eq 0) {
        Write-Color "All pairs already match. Nothing to apply." "Green"
        Wait-Back
        return
    }
    $allApplyResults = New-Object System.Collections.Generic.List[object]
    foreach ($pr in $changedResults) {
        $pair = @($pairs | Where-Object { $_.Name -eq $pr.Name }) | Select-Object -First 1
        if ($null -eq $pair) { continue }
        if ($pr.FileChanges -and $pr.FileChanges.Count -gt 0) {
            $normalChanges = @($pr.FileChanges | Where-Object { $_.Action -ne "CLEANUP" })
            $cleanupChanges = @($pr.FileChanges | Where-Object { $_.Action -eq "CLEANUP" })
            $hadApplicableChange = $false
            if ($normalChanges.Count -gt 0) {
                $pairResults = Invoke-ApplyFileChanges -Pair $pair -FileChanges $normalChanges -Policy $policy
                foreach ($r in $pairResults) { $allApplyResults.Add($r) | Out-Null }
                $hadApplicableChange = $true
            }
            if ($cleanupChanges.Count -gt 0) {
                $cleanupResults = Invoke-TempCleanupChanges -Pair $pair -FileChanges $cleanupChanges
                foreach ($r in $cleanupResults) { $allApplyResults.Add($r) | Out-Null }
                $hadApplicableChange = $true
            }
            if (-not $hadApplicableChange) {
                $allApplyResults.Add([pscustomobject]@{ Pair = $pr.Name; Action = "SKIP"; Status = "OK"; Path = ""; Message = "No changes found" }) | Out-Null
            }
        } else {
            $allApplyResults.Add([pscustomobject]@{ Pair = $pr.Name; Action = "SKIP"; Status = "OK"; Path = ""; Message = "No changes found" }) | Out-Null
        }
    }
    $finalResults = @($allApplyResults.ToArray())
    Show-ApplyResults -Results $finalResults -Title "Full Mirror Apply Results"
    Request-ClearPendingQueue
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

function Invoke-RobocopyForPairs {
    param(
        [object[]]$Pairs,
        [bool]$Preview,
        [ValidateSet("STRICT","UPDATE_KEEP_EXTRAS","MISSING_ONLY")]
        [string]$Policy
    )
    $results = New-Object System.Collections.Generic.List[object]
    $maxConcurrent = if ($null -ne $script:Config.RobocopyParallelBatches) { [int]$script:Config.RobocopyParallelBatches } else { 3 }
    if ($maxConcurrent -lt 1) { $maxConcurrent = 1 }

    # Pre-check all pairs, collect only valid ones
    $validPairs = New-Object System.Collections.Generic.List[object]
    foreach ($pair in $Pairs) {
        if (!(Test-Path -LiteralPath $pair.Source -PathType Container)) {
            $results.Add([pscustomobject]@{ Name=$pair.Name; Mode=$(if($Preview){"PREVIEW"}else{"APPLY"}); Policy=(Get-PolicyShort $Policy); Status="MISSING"; Code=16; Time=0; FilesTotal=0; NewFiles=0; UpdatedFiles=0; FilesSkipped=0; ExtraItems=0; FilesFailed=0; Message="Source missing" }) | Out-Null
            continue
        }
        if (!(Test-DestRootAvailable $pair.Dest)) {
            $results.Add([pscustomobject]@{ Name=$pair.Name; Mode=$(if($Preview){"PREVIEW"}else{"APPLY"}); Policy=(Get-PolicyShort $Policy); Status="ERROR"; Code=16; Time=0; FilesTotal=0; NewFiles=0; UpdatedFiles=0; FilesSkipped=0; ExtraItems=0; FilesFailed=0; Message="Destination root unavailable" }) | Out-Null
            continue
        }
        $validPairs.Add($pair) | Out-Null
    }

    if ($validPairs.Count -eq 0) { return @($results.ToArray()) }

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("mb_robocopy_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    try {
        $procForPairIndex = @{}
        $totalPairs = $validPairs.Count
        $nextPairIndex = 0
        $displayedCount = 0
        $procs = New-Object System.Collections.Generic.List[object]

        Write-Color "  Processing $totalPairs pairs ($maxConcurrent concurrent)" "DarkGray"
        $topLine = [Console]::CursorTop

        $startProcess = {
            param($Pair, $PairIndex, $LineIdx)
            $outFile = Join-Path $tempDir ([guid]::NewGuid().ToString('N') + ".txt")
            $args = Build-RobocopyArgs -Pair $Pair -Preview:$Preview -Policy $Policy
            $argStr = ConvertTo-ProcessArgumentString $args
            $startTime = Get-Date
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "robocopy.exe"
            $psi.Arguments = $argStr
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            $psi.RedirectStandardOutput = $true
            $psi.StandardOutputEncoding = [System.Text.Encoding]::GetEncoding(437)
            $proc = New-Object System.Diagnostics.Process
            $proc.StartInfo = $psi
            $proc.Start() | Out-Null
            $obj = [PSCustomObject]@{
                Process = $proc
                Pair = $Pair
                OutFile = $outFile
                StartTime = $startTime
                LineIdx = $LineIdx
                PairIndex = $PairIndex
                Done = $false
                RealElapsed = $null
            }
            [Console]::SetCursorPosition(0, $topLine + $LineIdx)
            $dn = $Pair.Name
            if ($dn.Length -gt 28) { $dn = $dn.Substring(0, 25) + "..." }
            Write-Host ("  {0,-30} | Scanning..." -f $dn) -ForegroundColor DarkGray
            return $obj
        }

        # Fill initial slots
        while ($nextPairIndex -lt $totalPairs -and $procs.Count -lt $maxConcurrent) {
            $obj = & $startProcess -Pair $validPairs[$nextPairIndex] -PairIndex $nextPairIndex -LineIdx $displayedCount
            $procForPairIndex[$nextPairIndex] = $obj
            $procs.Add($obj) | Out-Null
            $displayedCount++
            $nextPairIndex++
        }

        $frames = @('|', '/', '-', '\')
        $fi = 0
        [Console]::CursorVisible = $false

        while ($procs.Count -gt 0) {
            $fi = ($fi + 1) % $frames.Length

            # Check completed (reverse iteration for safe removal)
            for ($i = $procs.Count - 1; $i -ge 0; $i--) {
                $p = $procs[$i]
                $p.Process.Refresh()
                if ($p.Process.HasExited) {
                    $p.Done = $true
                    $elapsed = (Get-Date) - $p.StartTime
                    $p.RealElapsed = $elapsed
                    $tempCode = $p.Process.ExitCode
                    $outputText = $p.Process.StandardOutput.ReadToEnd()
                    [System.IO.File]::WriteAllText($p.OutFile, $outputText, [System.Text.Encoding]::Unicode)
                    $tempOutput = @($outputText -split '\r?\n')
                    $tempChangeSummary = Get-RobocopyChangeSummary -Output $tempOutput
                    $tempSummary = Get-RobocopySummary -Output $tempOutput
                    $tempIgnoreExtra = ($Policy -eq "UPDATE_KEEP_EXTRAS" -or $Policy -eq "MISSING_ONLY")
                    if ($tempIgnoreExtra) { $tempChangeSummary.ExtraFiles = 0; $tempChangeSummary.ExtraDirs = 0 }
                    $tempHasChanges = ($tempChangeSummary.NewFiles -gt 0 -or $tempChangeSummary.NewDirs -gt 0 -or $tempChangeSummary.UpdatedFiles -gt 0 -or $tempChangeSummary.ExtraFiles -gt 0 -or $tempChangeSummary.ExtraDirs -gt 0)
                    # Detect gaps: empty dirs and Arabic paths not resolvable from change lines
                    $summaryNewDirs = [math]::Max(0, $tempSummary.DirsCopied - $tempSummary.DirsSkipped)
                    $summaryNewFiles = [math]::Max(0, $tempSummary.FilesCopied - $tempSummary.FilesSkipped)
                    $hasMissingNewDirs = ($summaryNewDirs -gt $tempChangeSummary.NewDirs)
                    $hasMissingNewFiles = ($summaryNewFiles -gt $tempChangeSummary.NewFiles)
                    if ($summaryNewDirs -gt $tempChangeSummary.NewDirs) { $tempChangeSummary.NewDirs = $summaryNewDirs }
                    if ($summaryNewFiles -gt $tempChangeSummary.NewFiles) { $tempChangeSummary.NewFiles = $summaryNewFiles }
                    if (-not $tempIgnoreExtra) {
                        if ($tempSummary.DirsExtras -gt $tempChangeSummary.ExtraDirs) { $tempChangeSummary.ExtraDirs = $tempSummary.DirsExtras }
                        if ($tempSummary.FilesExtras -gt $tempChangeSummary.ExtraFiles) { $tempChangeSummary.ExtraFiles = $tempSummary.FilesExtras }
                    }
                    $tempHasChanges = ($tempChangeSummary.NewFiles -gt 0 -or $tempChangeSummary.NewDirs -gt 0 -or $tempChangeSummary.UpdatedFiles -gt 0 -or $tempChangeSummary.ExtraFiles -gt 0 -or $tempChangeSummary.ExtraDirs -gt 0)
                    if ($tempCode -ge 16) { $tempStatus = "ERROR" }
                    elseif ($tempHasChanges) { $tempStatus = "CHANGED" }
                    else { $tempStatus = "MATCHED" }
                    $tempColor = switch ($tempStatus) { "MATCHED" { "Green" } "CHANGED" { "Yellow" } default { "Red" } }
                    $tempMsg = (@($tempOutput | Select-Object -Last 2) -join " ")
                    if ($tempMsg.Length -gt 120) { $tempMsg = $tempMsg.Substring(0, 120) }
                    $tempChangeLines = @($tempOutput | Where-Object { Test-RobocopyChangeLine $_ })
                    if ($tempIgnoreExtra) {
                        $tempChangeLines = @($tempChangeLines | Where-Object { -not ([string]$_ -match '^\s*\*EXTRA') })
                    }
                    $p | Add-Member -NotePropertyName ParsedStatus -NotePropertyValue $tempStatus -Force
                    $p | Add-Member -NotePropertyName ParsedCode -NotePropertyValue $tempCode -Force
                    $p | Add-Member -NotePropertyName ParsedSummary -NotePropertyValue $tempSummary -Force
                    $p | Add-Member -NotePropertyName ParsedChangeSummary -NotePropertyValue $tempChangeSummary -Force
                    $p | Add-Member -NotePropertyName ParsedOutput -NotePropertyValue $tempOutput -Force
                    $p | Add-Member -NotePropertyName ParsedMessage -NotePropertyValue $tempMsg -Force
                    $p | Add-Member -NotePropertyName ParsedChanges -NotePropertyValue @($tempChangeLines | ForEach-Object { Get-RobocopyChangeText $_ }) -Force
                    $srcRoot = $p.Pair.Source
                    $dstRoot = Resolve-DestinationPath $p.Pair.Dest
                    $tempFileChanges = @($tempChangeLines | ForEach-Object { Convert-RobocopyLineToChange -Line $_ -SourceRoot $srcRoot -DestRoot $dstRoot } | Where-Object { $null -ne $_ })
                    # Resolve garbled paths and detect missing items (empty dirs, Arabic names)
                    $hasBadPaths = $false
                    foreach ($__fc in $tempFileChanges) { if ($__fc.RelPath -match '\?') { $hasBadPaths = $true; break } }
                    if ($hasBadPaths -or $hasMissingNewDirs -or $hasMissingNewFiles) {
                        $__resolved = New-Object System.Collections.Generic.List[object]
                        $__oem = [System.Text.Encoding]::GetEncoding(437)
                        # Resolve garbled paths by scanning parent dirs
                        foreach ($__fc in $tempFileChanges) {
                            if ($__fc.RelPath -match '\?') {
                                $__parts = $__fc.RelPath -split '\\'
                                $__garbledName = $__parts[-1]
                                $__parentRel = if ($__parts.Length -gt 1) { ($__parts[0..($__parts.Length-2)] -join '\') } else { "" }
                                $__searchRoot = if ($__fc.ChangeAction -eq "DELETE") { $dstRoot } else { $srcRoot }
                                $__parentFull = if ($__parentRel) { Join-PathSafe $__searchRoot $__parentRel } else { $__searchRoot }
                                $__actualName = $null
                                if (Test-Path -LiteralPath $__parentFull -PathType Container) {
                                    $__items = @(Get-ChildItem -LiteralPath $__parentFull -Force -ErrorAction SilentlyContinue)
                                    foreach ($__item in $__items) {
                                        $__oemName = $__oem.GetString($__oem.GetBytes($__item.Name))
                                        if ($__oemName -eq $__garbledName) { $__actualName = $__item.Name; break }
                                    }
                                }
                                if ($__actualName) {
                                    $__actualRel = if ($__parentRel) { "$__parentRel\$__actualName" } else { $__actualName }
                                    $__resolved.Add([PSCustomObject]@{ Action = $__fc.Action; Type = $__fc.Type; RelPath = $__actualRel; ChangeAction = $__fc.ChangeAction })
                                } else { $__resolved.Add($__fc) }
                            } else { $__resolved.Add($__fc) }
                        }
                        # Add missing empty directories
                        if ($hasMissingNewDirs) {
                            $__emptyDirs = @(Get-ChildItem -LiteralPath $srcRoot -Directory -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { (Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue).Count -eq 0 })
                            foreach ($__dir in $__emptyDirs) {
                                $__relPath = Get-RelativePath $srcRoot $__dir.FullName
                                $__destCheck = Join-PathSafe $dstRoot $__relPath
                                if (-not (Test-Path -LiteralPath $__destCheck -PathType Container)) {
                                    $__dup = $false
                                    foreach ($__ex in $__resolved) { if ($__ex.RelPath -eq $__relPath -and $__ex.Type -eq "DIR") { $__dup = $true; break } }
                                    if (-not $__dup) { $__resolved.Add([PSCustomObject]@{ Action = "MKDIR"; Type = "DIR"; RelPath = $__relPath; ChangeAction = "NEW" }) }
                                }
                            }
                        }
                        $tempFileChanges = @($__resolved.ToArray())
                    }
                    $p | Add-Member -NotePropertyName ParsedFileChanges -NotePropertyValue $tempFileChanges -Force
                    $dn = $p.Pair.Name
                    if ($dn.Length -gt 28) { $dn = $dn.Substring(0, 25) + "..." }
                    $elapsedStr = [math]::Round($elapsed.TotalSeconds, 1).ToString() + "s"
                    [Console]::SetCursorPosition(0, $topLine + $p.LineIdx)
                    Write-Host -NoNewline (" " * 80)
                    [Console]::SetCursorPosition(0, $topLine + $p.LineIdx)
                    Write-Host ("  {0,-30} ✓ {1} ({2})     " -f $dn, $tempStatus, $elapsedStr) -ForegroundColor $tempColor

                    # Remove from active list
                    $procs.RemoveAt($i)

                    # Start next pair if any remain
                    if ($nextPairIndex -lt $totalPairs) {
                        $obj = & $startProcess -Pair $validPairs[$nextPairIndex] -PairIndex $nextPairIndex -LineIdx $displayedCount
                        $procForPairIndex[$nextPairIndex] = $obj
                        $procs.Add($obj) | Out-Null
                        $displayedCount++
                        $nextPairIndex++
                    }
                }
            }

            # Update spinners for remaining running processes
            for ($i = 0; $i -lt $procs.Count; $i++) {
                $p = $procs[$i]
                $p.Process.Refresh()
                if (-not $p.Process.HasExited -and -not $p.Done) {
                    [Console]::SetCursorPosition(0, $topLine + $p.LineIdx)
                    $dn = $p.Pair.Name
                    if ($dn.Length -gt 28) { $dn = $dn.Substring(0, 25) + "..." }
                    $elapsed = (Get-Date) - $p.StartTime
                    $elapsedStr = [math]::Round($elapsed.TotalSeconds, 1).ToString() + "s"
                    $frame = $frames[($fi + $i) % $frames.Length]
                    Write-Host ("  {0,-30} {1} Scanning ({2})" -f $dn, $frame, $elapsedStr) -ForegroundColor DarkGray
                }
            }

            Start-Sleep -Milliseconds 200
        }

        [Console]::CursorVisible = $true

        # Parse results in original pair order
        for ($i = 0; $i -lt $totalPairs; $i++) {
            $p = $procForPairIndex[$i]
            $p.Process.WaitForExit()
            $elapsed = if ($null -ne $p.RealElapsed) { $p.RealElapsed } else { (Get-Date) - $p.StartTime }
            $pair = $p.Pair
            if ($null -ne $p.ParsedStatus) {
                $code = $p.ParsedCode
                $status = $p.ParsedStatus
                $summary = $p.ParsedSummary
                $changeSummary = $p.ParsedChangeSummary
                $msg = $p.ParsedMessage
                $changes = $p.ParsedChanges
                $fileChanges = $p.ParsedFileChanges
            } else {
                $code = $p.Process.ExitCode
                $output = @(Get-Content -LiteralPath $p.OutFile -Encoding Unicode -ErrorAction SilentlyContinue)
                $summary = Get-RobocopySummary -Output $output
                $changeSummary = Get-RobocopyChangeSummary -Output $output
                $ignoreExtra = ($Policy -eq "UPDATE_KEEP_EXTRAS" -or $Policy -eq "MISSING_ONLY")
                if ($ignoreExtra) {
                    $summary.FilesExtras = 0; $summary.DirsExtras = 0
                    $changeSummary.ExtraFiles = 0; $changeSummary.ExtraDirs = 0
                }
                $status = Decode-RobocopyExit $code
                $hasRealChanges = ($changeSummary.NewFiles -gt 0 -or $changeSummary.NewDirs -gt 0 -or $changeSummary.UpdatedFiles -gt 0 -or $changeSummary.ExtraFiles -gt 0 -or $changeSummary.ExtraDirs -gt 0)
                $summaryNewDirs = [math]::Max(0, $summary.DirsCopied - $summary.DirsSkipped)
                $summaryNewFiles = [math]::Max(0, $summary.FilesCopied - $summary.FilesSkipped)
                if ($summaryNewDirs -gt $changeSummary.NewDirs) { $changeSummary.NewDirs = $summaryNewDirs }
                if ($summaryNewFiles -gt $changeSummary.NewFiles) { $changeSummary.NewFiles = $summaryNewFiles }
                if (-not $ignoreExtra) {
                    if ($summary.DirsExtras -gt $changeSummary.ExtraDirs) { $changeSummary.ExtraDirs = $summary.DirsExtras }
                    if ($summary.FilesExtras -gt $changeSummary.ExtraFiles) { $changeSummary.ExtraFiles = $summary.FilesExtras }
                }
                $hasRealChanges = ($changeSummary.NewFiles -gt 0 -or $changeSummary.NewDirs -gt 0 -or $changeSummary.UpdatedFiles -gt 0 -or $changeSummary.ExtraFiles -gt 0 -or $changeSummary.ExtraDirs -gt 0)
                if ($hasRealChanges) { $status = "CHANGED" }
                elseif ($status -eq "CHANGED") { $status = "MATCHED" }
                $msg = (@($output | Select-Object -Last 2 | ForEach-Object { [string]$_ }) -join " ")
                if ($msg.Length -gt 120) { $msg = $msg.Substring(0, 120) }
                $changeLines = @($output | Where-Object { Test-RobocopyChangeLine $_ })
                if ($ignoreExtra) {
                    $changeLines = @($changeLines | Where-Object { -not ([string]$_ -match '^\s*\*EXTRA') })
                }
                $changes = @($changeLines | ForEach-Object { Get-RobocopyChangeText $_ })
                $fcSrcRoot = $pair.Source
                $fcDstRoot = Resolve-DestinationPath $pair.Dest
                $fileChanges = @($changeLines | ForEach-Object { Convert-RobocopyLineToChange -Line $_ -SourceRoot $fcSrcRoot -DestRoot $fcDstRoot } | Where-Object { $null -ne $_ })
            }
            $results.Add([pscustomobject]@{
                Name = $pair.Name
                Mode = $(if ($Preview) { "PREVIEW" } else { "APPLY" })
                Policy = Get-PolicyShort $Policy
                Status = $status
                Code = $code
                Time = [math]::Round($elapsed.TotalSeconds, 1)
                NewFiles = $changeSummary.NewFiles
                NewDirs = $changeSummary.NewDirs
                UpdatedFiles = $changeSummary.UpdatedFiles
                FilesSkipped = $summary.FilesSkipped
                ExtraItems = ($changeSummary.ExtraFiles + $changeSummary.ExtraDirs)
                FilesTotal = ($changeSummary.NewFiles + $changeSummary.NewDirs + $changeSummary.UpdatedFiles + $changeSummary.ExtraFiles + $changeSummary.ExtraDirs)
                FilesFailed = $summary.FilesFailed
                Message = $msg
                Changes = $changes
                FileChanges = $fileChanges
            }) | Out-Null
        }
        # Move cursor past all display lines
        [Console]::SetCursorPosition(0, $topLine + $displayedCount + 1)
    } finally {
        if (Test-Path -LiteralPath $tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
    return @($results.ToArray())
}

function Show-RobocopyResults {
    param([object[]]$Results, [string]$Title, [bool]$Pause = $true)
    Show-Header $Title "Robocopy summary"
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
    Write-Color "Total = New + Upd + Extra + Cleanup. New = missing files & folders. Upd = source updates. Extra = destination-only files/folders." "DarkGray"
    Write-Color "Cleanup = old script temp files (.mbtmp-*) that are safe to remove." "DarkGray"
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
    $task = Get-ScheduledTask -TaskName ([string]$script:Config.TaskName) -ErrorAction SilentlyContinue
    $watchers = @(Get-WatcherProcesses)
    Write-Color ("Pairs               : " + (Get-Pairs).Count) "Yellow"
    Write-Color ("Raw queue entries   : " + $entries.Count) "Yellow"
    Write-Color ("Effective entries   : " + $latest.Count) "Yellow"
    Write-Color ("Scheduled task      : " + $(if ($null -ne $task) { $task.State } else { "Not installed" })) $(if ($null -ne $task -and $task.State -eq "Running") { "Green" } else { "Yellow" })
    Write-Color ("Watcher processes   : " + $watchers.Count) $(if ($watchers.Count -gt 0) { "Green" } else { "Yellow" })
    Write-Host ""
    foreach ($pair in Get-Pairs) {
        $srcOk = Test-Path -LiteralPath $pair.Source -PathType Container
        $dstOk = Test-DestRootAvailable $pair.Dest
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
    $pairs += [pscustomobject]@{ Name=$name; Source=$source; Dest=$dest }
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
    $changedPath = $false
    if (-not [string]::IsNullOrWhiteSpace($source)) { $p.Source = Normalize-PathText $source }
    if (-not [string]::IsNullOrWhiteSpace($source)) { $changedPath = $true }
    if (-not [string]::IsNullOrWhiteSpace($dest)) { $p.Dest = Normalize-PathText $dest; $changedPath = $true }
    if ($changedPath) { $p.Name = Get-AutoPairName -Source $p.Source -Dest $p.Dest }
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
        if ($fullPath.Length -ge $src.Length -and $fullPath.Substring(0, $src.Length) -eq $src) {
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
        Write-Color "[6] RobocopyParallelBatches   = " "Yellow" -NoNewLine; Write-Color $script:Config.RobocopyParallelBatches "Cyan" -NoNewLine; Write-Color "   # Concurrent pairs during Full Mirror" "DarkGray"
        Write-Color "[7] DeleteDestOnSourceDelete= " "Yellow" -NoNewLine; Write-Color $script:Config.DeleteDestOnSourceDelete "Cyan" -NoNewLine; Write-Color "   # Delete dest file if source is deleted" "DarkGray"
        Write-Color "[8] DataDir                 = " "Yellow" -NoNewLine; Write-Color $script:Config.DataDir "Cyan" -NoNewLine; Write-Color "   # Program data folder" "DarkGray"
        Write-Color "[9] Manage Drive Maps" "Yellow"
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
            "7" { Toggle-BoolSetting "DeleteDestOnSourceDelete" }
            "8" { Set-StringSetting "DataDir" }
            "9" { Manage-DriveMapsMenu }
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
    Show-Header "Add Drive Map" "Example: Y: => \\server\share"
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

function Set-StringSetting {
    param([string]$Name)
    Show-Header "Set $Name" "Esc = cancel"
    $value = Read-LineOrEsc "New value: "
    if ($null -eq $value -or [string]::IsNullOrWhiteSpace($value)) { return }
    $script:Config.PSObject.Properties[$Name].Value = $value.Trim()
    Save-Config
    Initialize-App
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
        Stop-KnownWatcherProcesses
        New-HiddenWatchLauncher
        Remove-KnownScheduledTasks -KeepTaskName $taskName
        $action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$script:HiddenWatchLauncherPath`""
        $trigger = New-ScheduledTaskTrigger -AtLogOn
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
        $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "MiraQueue Backup watcher" -Force -ErrorAction Stop | Out-Null
        Write-Color ("Scheduled task installed: " + $taskName) "Green"
        Start-ScheduledTask -TaskName $taskName -ErrorAction Stop
        Start-Sleep -Milliseconds 600
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
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
    $vbsPtr = $script:ScriptDirPointerFile
    $vbs = @"
Set fso = CreateObject("Scripting.FileSystemObject")
Set file = fso.OpenTextFile("$vbsPtr", 1)
scriptDir = file.ReadLine()
file.Close
psPath = scriptDir & "\MiraQueue.ps1"
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & psPath & """ -Mode Watch"
Set shell = CreateObject("WScript.Shell")
shell.Run cmd, 0, True
"@
    Set-Content -LiteralPath $script:HiddenWatchLauncherPath -Value $vbs -Encoding ASCII
}

function Uninstall-Everything {
    Show-Header "Uninstall Everything" "Program data only - sources and destinations are preserved"
    if (-not (Test-IsAdministrator)) {
        Write-Color "Administrator permission is required to remove scheduled tasks cleanly." "Yellow"
        Write-Color "A UAC prompt will open now for this uninstall step only." "DarkGray"
        Invoke-ElevatedMode "Uninstall"
        Show-PostElevatedTaskStatus "Uninstall"
        return
    }
    Write-Color "This removes scheduled tasks, queue, logs, runtime data, generated config, and app-created shortcuts." "Yellow"
    Write-Color "It will NOT delete source files or backup destination files." "Green"
    Write-Host ""
    if (-not (Read-EnterOrEsc "Press Enter to uninstall everything, or Esc to cancel.")) { return }
    $taskName = [string]$script:Config.TaskName
    try {
        Stop-KnownWatcherProcesses
        Remove-KnownScheduledTasks -KeepTaskName ""
    } catch {}

    $safeDataDir = [System.IO.Path]::GetFullPath($script:DataDir)
    $localApp = [System.IO.Path]::GetFullPath($env:LOCALAPPDATA)
    if (Test-Path -LiteralPath $safeDataDir) {
        if ($safeDataDir.StartsWith($localApp, [System.StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $safeDataDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Color ("Removed data folder: " + $safeDataDir) "Green"
        } else {
            foreach ($runtimeFile in @($script:QueuePath, $script:LogPath, $script:ApplyLockPath, $script:ClearQueueRequestPath, $script:HiddenWatchLauncherPath, $script:ScriptDirPointerFile)) {
                if (Test-Path -LiteralPath $runtimeFile) {
                    Remove-Item -LiteralPath $runtimeFile -Force -ErrorAction SilentlyContinue
                    Write-Color ("Removed runtime file: " + $runtimeFile) "Green"
                }
            }
            try {
                if (@(Get-ChildItem -LiteralPath $safeDataDir -Force -ErrorAction SilentlyContinue).Count -eq 0) {
                    Remove-Item -LiteralPath $safeDataDir -Force -ErrorAction SilentlyContinue
                    Write-Color ("Removed empty data folder: " + $safeDataDir) "Green"
                } else {
                    Write-Color ("Data folder kept because it contains other files: " + $safeDataDir) "DarkYellow"
                }
            } catch {}
        }
    }

    foreach ($shortcut in @(
        (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\MiraQueue Backup.lnk"),
        (Join-Path ([Environment]::GetFolderPath("Desktop")) "MiraQueue Backup.lnk")
    )) {
        if (Test-Path -LiteralPath $shortcut) {
            Remove-Item -LiteralPath $shortcut -Force -ErrorAction SilentlyContinue
            Write-Color ("Removed shortcut: " + $shortcut) "Green"
        }
    }

    if (Test-Path -LiteralPath $script:ConfigPath) {
        Remove-Item -LiteralPath $script:ConfigPath -Force -ErrorAction SilentlyContinue
        Write-Color ("Removed config: " + $script:ConfigPath) "Green"
    }
    Write-Host ""
    Write-Color "Uninstall finished. Source and destination folders were not touched." "Green"
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
    param([ValidateSet("Install","RemoveTask","Uninstall")][string]$TargetMode)
    try {
        $cmd = "title MiraQueue Backup Admin && powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$script:ScriptPath`" -Mode $TargetMode -NoPause & timeout /t 3 /nobreak >nul"
        $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/d /c `"$cmd`"" -Verb RunAs -Wait -PassThru
        if ($proc.ExitCode -eq 0) {
            Write-Color "Elevated step finished." "Green"
        } else {
            Write-Color ("Elevated step finished with exit code: " + $proc.ExitCode) "Yellow"
        }
    } catch {
        Write-Color ("Could not start elevated PowerShell: " + $_.Exception.Message) "Red"
    }
}

function Show-PostElevatedTaskStatus {
    param([ValidateSet("Install","RemoveTask","Uninstall")][string]$Operation)
    Start-Sleep -Milliseconds 800
    Write-Host ""
    if ($Operation -eq "Install") {
        $task = Get-ScheduledTask -TaskName ([string]$script:Config.TaskName) -ErrorAction SilentlyContinue
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

    $remaining = @(Get-ScheduledTask -TaskName ([string]$script:Config.TaskName) -ErrorAction SilentlyContinue)
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
    param([string]$KeepTaskName = "")
    $knownTaskNames = @(
        [string]$script:Config.TaskName
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

    foreach ($name in $knownTaskNames) {
        if (-not [string]::IsNullOrWhiteSpace($KeepTaskName) -and $name -eq $KeepTaskName) { continue }
        $task = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
        if ($null -ne $task) {
            Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction Stop
            Write-Color ("Removed scheduled task: " + $name) "Green"
        }
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
        Remove-Item -LiteralPath $script:HiddenWatchLauncherPath -Force -ErrorAction SilentlyContinue
        Write-Color ("Removed hidden watcher launcher: " + $script:HiddenWatchLauncherPath) "Green"
    }
    Write-Host ""
    Write-Color "Scheduled watcher removal finished. Config, queue, logs, sources, and destinations were not touched." "Green"
    Wait-Back
}

function Stop-KnownWatcherProcesses {
    try {
        $watchers = @(Get-WatcherProcesses)
        foreach ($proc in $watchers) {
            try {
                Stop-Process -Id $proc.ProcessId -Force -ErrorAction Stop
                Write-Color ("Stopped watcher process: " + $proc.ProcessId) "Green"
            } catch {}
        }
    } catch {}
}

function Get-WatcherProcesses {
    try {
        return @(Get-CimInstance Win32_Process | Where-Object {
            $_.CommandLine -like '*MiraQueue.ps1*' -and
            $_.CommandLine -like '*-Mode Watch*' -and
            $_.ProcessId -ne $PID
        })
    } catch {
        return @()
    }
}

function Test-AllDriveMapsOnline {
    $allOnline = $true
    $offlineDrives = New-Object System.Collections.Generic.List[string]
    $seen = New-Object System.Collections.Generic.List[string]
    foreach ($pair in Get-Pairs) {
        try {
            $root = [System.IO.Path]::GetPathRoot($pair.Dest)
            if ([string]::IsNullOrWhiteSpace($root)) { continue }
            if ($seen.Contains($root)) { continue }
            $seen.Add($root) | Out-Null
            if (-not (Test-Path -LiteralPath $root -ErrorAction SilentlyContinue)) {
                $allOnline = $false
                $offlineDrives.Add($root.TrimEnd('\')) | Out-Null
            }
        } catch {}
    }
    return [pscustomobject]@{ Online = $allOnline; OfflineDrives = @($offlineDrives.ToArray()) }
}

function Show-MainMenu {
    while ($true) {
        Show-Header
        Write-Color ("Config: " + $script:ConfigPath) "DarkGray"
        $pairsCount = (Get-Pairs).Count
        $qEntries = @(Read-QueueEntries)
        $qLatest = @(Get-LatestQueueEntries $qEntries)
        $qLatest = @(Remove-OrphanedUpserts $qLatest)
        $qVisible = @(Get-VisiblePendingEntries $qLatest)
        $watcherCount = @(Get-WatcherProcesses).Count
        $watcherStatus = if ($watcherCount -gt 0) { "RUN" } else { "STOP" }
        $driveStatus = Test-AllDriveMapsOnline
        $statusColor = if ($driveStatus.Online) { "Green" } else { "Red" }
        Write-Color ("Pairs: $pairsCount    Pending: " + $qVisible.Count + "    Watcher: " + $watcherStatus) $statusColor
        if (-not $driveStatus.Online) {
            Write-Color ("⚠  Drive " + ($driveStatus.OfflineDrives -join ", ") + " is not available") "Yellow"
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
            "1" { Invoke-ApplyPending }
            "2" { Show-PendingPreview }
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

Initialize-App

switch ($Mode) {
    "Menu" { Show-MainMenu }
    "Watch" { Start-Watcher }
    "PreviewPending" { Show-PendingPreview }
    "ApplyPending" { Invoke-ApplyPending }
    "FullMirror" { Invoke-FullMirror }
    "Status" { Show-Status }
    "Install" { Install-Required }
    "RemoveTask" { Remove-ScheduledWatcherOnly }
    "Uninstall" { Uninstall-Everything }
}

