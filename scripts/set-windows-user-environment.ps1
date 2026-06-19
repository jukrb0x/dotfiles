$ErrorActionPreference = "Stop"

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

Write-Host "Restart apps and terminals to inherit updated user environment variables."
