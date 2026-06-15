$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ScriptPath = Join-Path $RepoRoot "MiraQueue.ps1"
$ReferencePath = Join-Path $RepoRoot "docs/explanation/15-function-reference.md"

if (!(Test-Path -LiteralPath $ReferencePath)) { throw "Function reference is missing." }

$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$tokens, [ref]$errors)
if ($errors.Count -gt 0) { throw "Cannot parse MiraQueue.ps1 for coverage." }

$functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) |
    Sort-Object { $_.Extent.StartLineNumber }

$reference = Get-Content -LiteralPath $ReferencePath -Raw -Encoding UTF8
$missing = New-Object System.Collections.Generic.List[string]

foreach ($function in $functions) {
    $heading = "### " + $function.Name
    if ($reference -notmatch [regex]::Escape($heading)) {
        $missing.Add($function.Name) | Out-Null
    }
}

if ($missing.Count -gt 0) {
    throw "Undocumented functions: $($missing -join ', ')"
}

Write-Host "Function documentation coverage passed for $($functions.Count) functions."
