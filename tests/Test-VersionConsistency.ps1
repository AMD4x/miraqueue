$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$RequiredVersion = "V1.0.0"

$requiredFiles = @(
    "MiraQueue.ps1",
    "README.md",
    "CHANGELOG.md",
    "docs/release-v1.0.0.md",
    "examples/MiraQueue.config.example.json"
)

foreach ($relative in $requiredFiles) {
    $path = Join-Path $RepoRoot $relative
    if (!(Test-Path -LiteralPath $path)) { throw "Required versioned file missing: $relative" }
    $content = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    if ($content -notmatch [regex]::Escape($RequiredVersion)) {
        throw "$relative does not contain $RequiredVersion."
    }
}

$textFiles = Get-ChildItem -LiteralPath $RepoRoot -Recurse -File |
    Where-Object {
        $_.FullName -notmatch '\\docs\\media\\' -and
        $_.Extension -notin @(".gif", ".png", ".jpg", ".jpeg")
    }

foreach ($file in $textFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($content -match 'Version\s*=\s*"1\.0\.0"' -or $content -match '"Version"\s*:\s*"1\.0\.0"') {
        throw "Bare version value found in $($file.FullName)."
    }
}

Write-Host "Version consistency checks passed."
