#Requires -Version 7.1
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "lib\WindowsSetup.psm1") -Force -DisableNameChecking

$repoRoot = Split-Path -Parent $PSScriptRoot
$appManifestPath = Join-Path $repoRoot "packages\windows-winget-apps.psd1"
$Apps = @(Read-WinGetPackageSpecs -Path $appManifestPath)

foreach ($app in $Apps) {
    Install-WinGetPackageSpec -Spec $app
}

& (Join-Path $PSScriptRoot "set-windows-user-environment.ps1")
& (Join-Path $PSScriptRoot "set-windows-user-path.ps1")
