#Requires -Version 7.1
param(
    [switch] $Managed,
    [switch] $All,
    [switch] $IncludePinned,
    [switch] $IncludeUnknown,
    [Parameter(ValueFromRemainingArguments = $true)] [string[]] $RemainingArgs
)

$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "lib\WindowsSetup.psm1") -Force -DisableNameChecking

if ($RemainingArgs -contains "--managed") { $Managed = $true }
if ($RemainingArgs -contains "--all") { $All = $true }
if ($RemainingArgs -contains "--include-pinned") { $IncludePinned = $true }
if ($RemainingArgs -contains "--include-unknown") { $IncludeUnknown = $true }

if ($Managed -and $All) {
    throw "Use either --managed or --all, not both."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestPaths = @(
    Join-Path $repoRoot "packages\windows-winget-required.psd1"
    Join-Path $repoRoot "packages\windows-winget-apps.psd1"
    Join-Path $repoRoot "packages\windows-winget-toolchains.psd1"
)

function Invoke-WinGetUpgrade {
    param([Parameter(Mandatory)] [string[]] $Arguments)

    winget upgrade @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "winget upgrade failed with exit code $LASTEXITCODE"
    }
}

$commonArgs = @("--disable-interactivity")
if ($IncludePinned) { $commonArgs += "--include-pinned" }
if ($IncludeUnknown) { $commonArgs += "--include-unknown" }

if ($All) {
    $arguments = @(
        "--all",
        "--silent",
        "--accept-source-agreements",
        "--accept-package-agreements"
    ) + $commonArgs

    Invoke-WinGetUpgrade -Arguments $arguments
    return
}

if (-not $Managed) {
    winget upgrade @commonArgs
    if ($LASTEXITCODE -ne 0) {
        throw "winget upgrade preview failed with exit code $LASTEXITCODE"
    }

    return
}

foreach ($manifestPath in $manifestPaths) {
    foreach ($package in Read-WinGetPackageSpecs -Path $manifestPath) {
        if (-not $package.Id) {
            $displayName = if ($package.Name) { $package.Name } else { $package.PackageName }
            Write-Host "Skipping $displayName because managed upgrades require a WinGet Id."
            continue
        }

        $arguments = @(
            "--id", $package.Id,
            "--exact",
            "--source", $package.Source,
            "--silent",
            "--accept-source-agreements",
            "--accept-package-agreements"
        ) + $commonArgs

        Invoke-WinGetUpgrade -Arguments $arguments
    }
}
