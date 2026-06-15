$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ScriptPath = Join-Path $RepoRoot "MiraQueue.ps1"
$LauncherPath = Join-Path $RepoRoot "Start_MiraQueue.cmd"

if (!(Test-Path -LiteralPath $ScriptPath)) { throw "MiraQueue.ps1 is missing." }
if (!(Test-Path -LiteralPath $LauncherPath)) { throw "Start_MiraQueue.cmd is missing." }

$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) {
    $messages = ($errors | ForEach-Object { $_.Message }) -join "; "
    throw "PowerShell parse failed: $messages"
}

$scriptText = Get-Content -LiteralPath $ScriptPath -Raw -Encoding UTF8
$launcherText = Get-Content -LiteralPath $LauncherPath -Raw -Encoding ASCII

foreach ($mode in @("Menu","Watch","PreviewPending","ApplyPending","FullMirror","Status","Install","RemoveTask","Uninstall")) {
    if ($scriptText -notmatch [regex]::Escape($mode)) { throw "Missing mode: $mode" }
}

foreach ($required in @(
    "MiraQueue.config.json",
    "MiraQueue.queue.ndjson",
    "MiraQueue.log",
    "MiraQueue.apply.lock",
    "MiraQueue.clear-queue",
    "MiraQueue.watch.hidden.vbs",
    "MiraQueue.scriptdir.txt",
    "%LOCALAPPDATA%\MiraQueue",
    "TaskName = `"MiraQueue`"",
    "Version = `"V1.0.0`""
)) {
    if ($scriptText -notmatch [regex]::Escape($required)) { throw "Missing runtime string: $required" }
}

if ($launcherText -notmatch [regex]::Escape("MiraQueue.ps1")) { throw "Launcher does not target MiraQueue.ps1." }
if ($launcherText -notmatch [regex]::Escape("title MiraQueue")) { throw "Launcher title is not MiraQueue." }

$oldTerms = @(
    ("Mirror" + "Backup"),
    ("Mirror" + " Backup"),
    ("Mirror" + "Backup" + "Portable"),
    ("Mirror" + "Backup" + "AgentPS"),
    ("Start_" + "Mirror" + "Backup")
)

$textFiles = Get-ChildItem -LiteralPath $RepoRoot -Recurse -File |
    Where-Object {
        $_.FullName -notmatch '\\docs\\media\\' -and
        $_.Extension -notin @(".gif", ".png", ".jpg", ".jpeg")
    }

foreach ($file in $textFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
    foreach ($term in $oldTerms) {
        if ($content -like "*$term*") { throw "Old project name found in $($file.FullName)." }
    }
}

$blockedWord = ("i" + "con")
$blockedExt = ("." + "i" + "co")
foreach ($file in Get-ChildItem -LiteralPath $RepoRoot -Recurse -File) {
    if ($file.Extension -ieq $blockedExt) { throw "Blocked asset extension found: $($file.FullName)" }
    if ($file.Name -like "*$blockedWord*") { throw "Blocked asset name found: $($file.FullName)" }
}

foreach ($file in $textFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($content -match $blockedWord -or $content -match [regex]::Escape($blockedExt)) {
        throw "Blocked asset reference found in $($file.FullName)."
    }
}

$privateName = "publish-helper-private"
if (Test-Path -LiteralPath (Join-Path $RepoRoot $privateName)) {
    throw "Private publishing helper must not be inside the public repo."
}

Write-Host "Static repository checks passed."
