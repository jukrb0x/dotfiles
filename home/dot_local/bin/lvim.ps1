#Requires -Version 7.1
$ErrorActionPreference = "Stop"

$env:XDG_DATA_HOME = $env:XDG_DATA_HOME ?? $env:APPDATA
$env:XDG_CONFIG_HOME = $env:XDG_CONFIG_HOME ?? "$HOME\.config"
$env:XDG_STATE_HOME = $env:XDG_STATE_HOME ?? "$env:LOCALAPPDATA\state"
$env:XDG_CACHE_HOME = $env:XDG_CACHE_HOME ?? "$env:LOCALAPPDATA\cache"

$env:LUNARVIM_RUNTIME_DIR = $env:LUNARVIM_RUNTIME_DIR ?? "$env:XDG_DATA_HOME\lunarvim"
$env:LUNARVIM_CONFIG_DIR = $env:LUNARVIM_CONFIG_DIR ?? "$env:XDG_CONFIG_HOME\lvim"
$env:LUNARVIM_CACHE_DIR = $env:LUNARVIM_CACHE_DIR ?? "$env:XDG_CACHE_HOME\lvim"
$env:LUNARVIM_BASE_DIR = $env:LUNARVIM_BASE_DIR ?? "$env:LUNARVIM_RUNTIME_DIR\lvim"

$init = Join-Path $env:LUNARVIM_BASE_DIR "init.lua"
if (Test-Path -LiteralPath $init) {
    nvim -u $init @args
} else {
    # The launcher is managed, but the LunarVim runtime is optional.
    nvim @args
}
