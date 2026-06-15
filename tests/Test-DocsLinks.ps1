$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

$required = @(
    "README.md",
    "docs/index.md",
    "docs/quick-start.md",
    "docs/installation.md",
    "docs/configuration.md",
    "docs/safety.md",
    "docs/troubleshooting.md",
    "docs/release-v1.0.0.md",
    "docs/media/miraqueue-overview.gif",
    "docs/media/manage-paths-demo.gif",
    "docs/media/preview-apply-pending.gif",
    "docs/media/full-mirror-policies.gif"
)

foreach ($relative in $required) {
    if (!(Test-Path -LiteralPath (Join-Path $RepoRoot $relative))) {
        throw "Required documentation file missing: $relative"
    }
}

$markdownFiles = Get-ChildItem -LiteralPath $RepoRoot -Recurse -File -Filter "*.md"
$linkPattern = '!?\[[^\]]*\]\(([^)]+)\)'

foreach ($file in $markdownFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    foreach ($match in [regex]::Matches($content, $linkPattern)) {
        $target = $match.Groups[1].Value.Trim()
        if ($target -match '^(https?:|mailto:|#)') { continue }
        $targetNoAnchor = ($target -split '#')[0]
        if ([string]::IsNullOrWhiteSpace($targetNoAnchor)) { continue }
        $base = Split-Path -Parent $file.FullName
        $resolved = Join-Path $base $targetNoAnchor
        if (!(Test-Path -LiteralPath $resolved)) {
            throw "Broken link in $($file.FullName): $target"
        }
    }
}

Write-Host "Documentation link checks passed."
