#Requires -Version 7.1
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$configTemplatePath = Join-Path $repoRoot "home\.chezmoi.toml.tmpl"
$configTemplate = Get-Content -LiteralPath $configTemplatePath -Raw

if ($configTemplate -notmatch '(?ms)^\[data\]\s*^\s*manageShellExternals\s*=\s*true\s*$') {
    throw "Fresh chezmoi configuration should enable managed shell externals."
}

Write-Host "shell externals tests passed."
