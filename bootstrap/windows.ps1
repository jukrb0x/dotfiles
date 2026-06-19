$ErrorActionPreference = "Stop"

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
        $path = [IO.Path]::GetFullPath($xdgEnvironment[$name])
        [Environment]::SetEnvironmentVariable($name, $path, "User")
        Set-Item -Path "Env:$name" -Value $path
        Write-Host "Set user $name to $path."
    }
}

function Test-WinGetPackageInstalled {
    param(
        [Parameter(Mandatory)] [string] $Id,
        [string] $Source = "winget"
    )

    winget list --id $Id --exact --source $Source --disable-interactivity | Out-Null
    return $LASTEXITCODE -eq 0
}

function Install-WinGetPackage {
    param(
        [Parameter(Mandatory)] [string] $Id,
        [string] $Source = "winget",
        [string] $Name = $Id
    )

    if (Test-WinGetPackageInstalled -Id $Id -Source $Source) {
        Write-Host "$Name is already installed."
        return
    }

    Write-Host "Installing $Name from $Source..."

    $arguments = @(
        "install"
        "--id", $Id
        "--exact"
        "--source", $Source
        "--silent"
        "--disable-interactivity"
        "--accept-source-agreements"
        "--accept-package-agreements"
    )

    winget @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "winget install failed for $Id with exit code $LASTEXITCODE"
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
    Install-WinGetPackage $package
}

Set-ChezmoiPowerShellInterpreter

Write-Host "Bootstrap complete. Open PowerShell 7, then run:"
Write-Host "  chezmoi init https://github.com/jukrb0x/dotfiles.git"
Write-Host "  chezmoi apply"
