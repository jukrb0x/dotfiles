$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "lib\WindowsSetup.psm1") -Force -DisableNameChecking

$xdgEnvironment = [ordered]@{
    # rmux (and other ~-based tools) resolve "~" from $HOME, which PowerShell
    # does not export as an environment variable by default. Without it, rmux
    # cannot find ~/.rmux.conf when launched from PowerShell.
    HOME             = $HOME
    XDG_CONFIG_HOME  = Join-Path $HOME ".config"
    XDG_DATA_HOME    = $env:APPDATA
    XDG_STATE_HOME   = Join-Path $env:LOCALAPPDATA "state"
    XDG_CACHE_HOME   = Join-Path $env:LOCALAPPDATA "cache"
    # Yazi ignores XDG_CONFIG_HOME and hardcodes %APPDATA%\yazi\config on
    # Windows, so point it at the shared ~/.config/yazi tree explicitly. The
    # value must be absolute and must name the directory that directly contains
    # yazi.toml; yazi silently falls back to its default otherwise.
    YAZI_CONFIG_HOME = Join-Path $HOME ".config\yazi"
}

foreach ($name in $xdgEnvironment.Keys) {
    Set-ManagedUserEnvironment -Name $name -Value $xdgEnvironment[$name]
}

Write-Host "Restart apps and terminals to inherit updated user environment variables."
