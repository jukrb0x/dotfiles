$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "lib\WindowsSetup.psm1") -Force -DisableNameChecking

$paths = @(
    (Join-Path $env:APPDATA "..\bin"),
    (Join-Path $HOME ".local\bin"),
    (Join-Path $HOME "scoop\shims"),
    (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links"),
    (Join-Path $env:ProgramFiles "7-Zip"),
    "C:\msys64\ucrt64\bin"
)

Add-ManagedUserPath -Path $paths

Write-Host "Updated user PATH. Restart terminals to inherit it."
