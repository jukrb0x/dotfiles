#Requires -Version 7.1
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $repoRoot "home"

function Assert-True {
    param(
        [Parameter(Mandatory)] [bool] $Condition,
        [Parameter(Mandatory)] [string] $Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Contains {
    param(
        [Parameter(Mandatory)] [string] $Content,
        [Parameter(Mandatory)] [string] $Expected,
        [Parameter(Mandatory)] [string] $Message
    )

    Assert-True $Content.Contains($Expected) "$Message`nMissing: $Expected"
}

function Render-SourceTemplate {
    param(
        [Parameter(Mandatory)] [string] $RelativePath,
        [Parameter(Mandatory)] [ValidateSet("windows", "linux", "darwin")] [string] $OperatingSystem
    )

    $path = Join-Path $sourceRoot $RelativePath
    Assert-True (Test-Path -LiteralPath $path) "Expected source template does not exist: $RelativePath"

    $override = @{ chezmoi = @{ os = $OperatingSystem } } | ConvertTo-Json -Compress
    $rendered = & chezmoi execute-template --override-data $override -f $path
    if ($LASTEXITCODE -ne 0) {
        throw "chezmoi failed to render $RelativePath for $OperatingSystem."
    }
    return ($rendered -join "`n")
}

# --- Source layout ---

$yaziRoot = Join-Path $sourceRoot "dot_config/yazi"
foreach ($relative in @(
    "yazi.toml",
    "theme.toml",
    "flavors/kanagawa.yazi/flavor.toml",
    "flavors/kanagawa.yazi/tmtheme.xml"
)) {
    $path = Join-Path $yaziRoot $relative
    Assert-True (Test-Path -LiteralPath $path) "Yazi config must be managed at the shared XDG path: dot_config/yazi/$relative"
}

# Flavor files resolve relative to the config home, so a missed flavor file
# degrades theming silently instead of failing loudly.
Assert-Contains `
    (Get-Content -LiteralPath (Join-Path $yaziRoot "theme.toml") -Raw) `
    'dark = "kanagawa"' `
    "The theme must still select the bundled kanagawa flavor after the move."

# Assert on home/AppData itself, not home/AppData/Roaming/yazi: `git mv` leaves
# emptied parent directories behind, and chezmoi walks the source tree on disk,
# so leftover empty dirs would create a spurious ~/AppData tree on Unix.
Assert-True `
    (-not (Test-Path -LiteralPath (Join-Path $sourceRoot "AppData"))) `
    "home/AppData must not exist; empty leftover directories become empty target directories."

# --- Ignore rendering ---

foreach ($os in @("windows", "linux", "darwin")) {
    $ignore = Render-SourceTemplate ".chezmoiignore.tmpl" $os
    $lines = $ignore -split "`n" | ForEach-Object { $_.Trim() }

    Assert-True `
        (-not ($lines | Where-Object { $_ -like ".config/yazi*" })) `
        "$os must manage ~/.config/yazi; no ignore entry may exclude it."
    Assert-True `
        (-not ($lines | Where-Object { $_ -like "AppData*" })) `
        "$os must not reference AppData in .chezmoiignore; the source tree is gone."
}

Write-Output "Yazi configuration tests passed."
