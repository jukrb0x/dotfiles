#Requires -Version 7.1
$ErrorActionPreference = "Stop"

if (-not (Get-Command nvim -ErrorAction SilentlyContinue)) {
    throw "Neovim is required before installing LunarVim."
}

$env:LV_BRANCH = "release-1.4/neovim-0.9"
Invoke-WebRequest "https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.4/neovim-0.9/utils/installer/install.ps1" -UseBasicParsing |
    Invoke-Expression
