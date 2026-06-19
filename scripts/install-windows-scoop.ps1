#Requires -Version 7.1
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$packageFile = Join-Path $repoRoot "packages\windows-scoop.txt"
$setUserEnvironmentScript = Join-Path $PSScriptRoot "set-windows-user-environment.ps1"
$setUserPathScript = Join-Path $PSScriptRoot "set-windows-user-path.ps1"

if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Scoop..."
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod -Uri https://get.scoop.sh -OutFile "$env:TEMP\install-scoop.ps1"
    & "$env:TEMP\install-scoop.ps1" -RunAsAdmin
}

& $setUserEnvironmentScript
& $setUserPathScript

$packages = @(Get-Content $packageFile |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith("#") })

if ($packages.Count -gt 0) {
    scoop install @packages
}
