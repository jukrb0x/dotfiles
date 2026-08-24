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

# --- Windows environment wiring ---

# Assert the whole assignment, not just ".config\yazi": a substring check would
# still pass if the base changed to $env:APPDATA, which is the exact regression
# that matters.
$envAssignment = 'YAZI_CONFIG_HOME = Join-Path $HOME ".config\yazi"'

foreach ($relative in @("scripts/set-windows-user-environment.ps1", "bootstrap/windows.ps1")) {
    $path = Join-Path $repoRoot $relative
    Assert-True (Test-Path -LiteralPath $path) "Expected script does not exist: $relative"
    Assert-Contains `
        (Get-Content -LiteralPath $path -Raw) `
        $envAssignment `
        "$relative must set YAZI_CONFIG_HOME; yazi ignores XDG_CONFIG_HOME on Windows."
}

# The chezmoiscript delegates rather than duplicating the assignment, so it must
# NOT carry the literal — that would be a third drift site.
$chezmoiScript = Join-Path $sourceRoot ".chezmoiscripts/run_after_05-windows-user-environment.ps1.tmpl"
$chezmoiScriptText = Get-Content -LiteralPath $chezmoiScript -Raw
Assert-Contains `
    $chezmoiScriptText `
    'set-windows-user-environment.ps1' `
    "The chezmoiscript must keep delegating to the shared environment script."
Assert-True `
    (-not $chezmoiScriptText.Contains("YAZI_CONFIG_HOME")) `
    "The chezmoiscript must delegate, not duplicate, the YAZI_CONFIG_HOME assignment."

# --- Runtime check (Windows only, and only once the config has been applied) ---

# Gate on the applied config, NOT on $persisted. Gating on the variable would make
# the single highest-consequence regression invisible: the old
# %APPDATA%\yazi\config tree is deliberately left in place, so if the variable is
# missing, yazi loads that stale shadow copy *successfully* -- no error, no missing
# file -- and edits to ~/.config/yazi silently have no effect. Once the destination
# exists, the variable is mandatory, so assert it rather than skipping.
$persisted = [Environment]::GetEnvironmentVariable('YAZI_CONFIG_HOME', 'User')
$applied = Test-Path -LiteralPath (Join-Path $HOME ".config\yazi\yazi.toml")

if ($IsWindows -and (Get-Command yazi -ErrorAction SilentlyContinue) -and $applied) {
    Assert-True `
        ([bool]$persisted) `
        "~/.config/yazi is applied but YAZI_CONFIG_HOME is not persisted; yazi will silently load the stale %APPDATA%\yazi\config copy instead."

    Assert-True `
        ([IO.Path]::IsPathRooted($persisted)) `
        "YAZI_CONFIG_HOME must be absolute; yazi silently ignores relative values. Actual: $persisted"

    $expected = Join-Path $HOME ".config\yazi"
    Assert-True `
        ($persisted -eq $expected) `
        "Persisted YAZI_CONFIG_HOME must be $expected. Actual: $persisted"

    # Read the persisted User-scope value explicitly rather than trusting the
    # current session: Set-ManagedUserEnvironment only injects into the calling
    # session, so a shell started before `chezmoi apply` would report the old path.
    #
    # Select-Object -First 1 forces a scalar. Where-Object unwraps zero matches to
    # $null and one match to a string, but 2+ matches would yield an array, and
    # `-match` on an array filters instead of returning a bool -- which Assert-True
    # would then coerce to $true even if only a wrong-path line matched.
    $debug = & yazi --debug 2>&1 | Out-String
    $configLine = $debug -split "`n" |
        Where-Object { $_ -match '^\s+Yazi\s+:' } |
        Select-Object -First 1

    Assert-True `
        ($null -ne $configLine) `
        "yazi --debug must report a resolved Yazi config path."
    Assert-True `
        ($configLine -match [regex]::Escape((Join-Path ".config" "yazi"))) `
        "yazi must resolve its config under .config\yazi. Actual: $($configLine.Trim())"
} else {
    Write-Output "Skipping yazi runtime check (not a Windows PowerShell session, yazi missing, or ~/.config/yazi not applied yet)."
}

Write-Output "Yazi configuration tests passed."
