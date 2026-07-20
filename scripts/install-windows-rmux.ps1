#Requires -Version 7.1
[CmdletBinding()]
param(
    [string]$ManifestPath = "",
    [string]$HomePath = $HOME
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $repoRoot "packages\windows-rmux.psd1"
}

Import-Module (Join-Path $PSScriptRoot "lib\RmuxInstaller.psm1") -Force -DisableNameChecking
$spec = Read-RmuxReleaseSpec -Path $ManifestPath
$result = Install-RmuxRelease -Spec $spec -HomePath $HomePath
if ($result.Changed) {
    Write-Host "Installed $($spec.Tag) from $($result.Source) to $($result.InstallDir)."
} else {
    Write-Host "RMUX $($spec.Tag) is already installed at $($result.InstallDir)."
}
