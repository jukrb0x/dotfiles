$ErrorActionPreference = "Stop"

Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) "scripts\lib\WindowsSetup.psm1") -Force -DisableNameChecking

function Set-ChezmoiPowerShellInterpreter {
    $configDir = Join-Path $HOME ".config\chezmoi"
    $configFile = Join-Path $configDir "chezmoi.toml"

    New-Item -ItemType Directory -Path $configDir -Force | Out-Null

    $block = @"
[interpreters.ps1]
    command = "pwsh"
    args = ["-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File"]
"@

    if (Test-Path $configFile) {
        $config = Get-Content $configFile -Raw
        if ($config -notmatch '(?m)^\[interpreters\.ps1\]') {
            $config.TrimEnd() + "`n`n" + $block + "`n" | Set-Content -Path $configFile -Encoding UTF8
        }
    } else {
        $block + "`n" | Set-Content -Path $configFile -Encoding UTF8
    }
}

function Set-WindowsUserEnvironment {
    $xdgEnvironment = [ordered]@{
        XDG_CONFIG_HOME = Join-Path $HOME ".config"
        XDG_DATA_HOME   = $env:APPDATA
        XDG_STATE_HOME  = Join-Path $env:LOCALAPPDATA "state"
        XDG_CACHE_HOME  = Join-Path $env:LOCALAPPDATA "cache"
    }

    foreach ($name in $xdgEnvironment.Keys) {
        Set-ManagedUserEnvironment -Name $name -Value $xdgEnvironment[$name]
    }
}
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
Set-WindowsUserEnvironment

$BootstrapPackages = @(
    "Git.Git",
    "Microsoft.PowerShell",
    "twpayne.chezmoi"
)

foreach ($package in $BootstrapPackages) {
    Install-WinGetPackageSpec -Spec (Parse-WinGetPackageSpec $package)
}

Set-ChezmoiPowerShellInterpreter

Write-Host "Bootstrap complete. Open PowerShell 7, then run:"
Write-Host "  chezmoi init https://github.com/jukrb0x/dotfiles.git"
Write-Host "  chezmoi apply"
