#Requires -Version 7.1
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot "scripts\update-windows-winget.ps1"
$script = Get-Content -LiteralPath $scriptPath -Raw

function Assert-Match {
    param(
        [Parameter(Mandatory)] [string] $Text,
        [Parameter(Mandatory)] [string] $Pattern,
        [Parameter(Mandatory)] [string] $Message
    )

    if ($Text -notmatch $Pattern) {
        throw $Message
    }
}

function Assert-NoMatch {
    param(
        [Parameter(Mandatory)] [string] $Text,
        [Parameter(Mandatory)] [string] $Pattern,
        [Parameter(Mandatory)] [string] $Message
    )

    if ($Text -match $Pattern) {
        throw $Message
    }
}

Assert-Match $script '\[switch\]\s*\$Managed' "update-windows-winget.ps1 should expose -Managed."
Assert-Match $script '\[switch\]\s*\$All' "update-windows-winget.ps1 should expose -All."
Assert-Match $script '\[switch\]\s*\$IncludePinned' "update-windows-winget.ps1 should expose -IncludePinned."
Assert-Match $script '\[switch\]\s*\$IncludeUnknown' "update-windows-winget.ps1 should expose -IncludeUnknown."
Assert-Match $script 'ValueFromRemainingArguments\s*=\s*\$true' "update-windows-winget.ps1 should capture remaining args for double-hyphen options."
Assert-Match $script '\$RemainingArgs\s+-contains\s+"--managed"' "update-windows-winget.ps1 should support --managed."
Assert-Match $script '\$RemainingArgs\s+-contains\s+"--all"' "update-windows-winget.ps1 should support --all."
Assert-Match $script '\$RemainingArgs\s+-contains\s+"--include-pinned"' "update-windows-winget.ps1 should support --include-pinned."
Assert-Match $script '\$RemainingArgs\s+-contains\s+"--include-unknown"' "update-windows-winget.ps1 should support --include-unknown."
Assert-Match $script 'windows-winget-required\.psd1' "update-windows-winget.ps1 should read required packages."
Assert-Match $script 'windows-winget-apps\.psd1' "update-windows-winget.ps1 should read app packages."
Assert-Match $script 'windows-winget-toolchains\.psd1' "update-windows-winget.ps1 should read toolchain packages."
Assert-Match $script 'winget\s+upgrade' "update-windows-winget.ps1 should call winget upgrade."
Assert-Match $script '--id' "Managed upgrades should target package ids."
Assert-Match $script '--exact' "Managed upgrades should use exact matching."
Assert-Match $script '--all' "update-windows-winget.ps1 should support explicit all-package upgrades."
Assert-Match $script 'Skipping .* managed upgrades require a WinGet Id' "Managed upgrades should skip PackageName-only entries."
Assert-NoMatch $script 'winget\s+upgrade\s+--all' "update-windows-winget.ps1 should not default to winget upgrade --all."

Write-Host "windows-winget-update tests passed."
