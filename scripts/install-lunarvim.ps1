#Requires -Version 7.1
$ErrorActionPreference = "Stop"
$source = Get-Content -LiteralPath (Join-Path $PSScriptRoot "..\packages\lunarvim.env") -Raw | ConvertFrom-StringData
# The upstream PowerShell installer reads these PowerShell variables.
$LV_REMOTE = $source.LV_REMOTE
$LV_BRANCH = $source.LV_BRANCH
$url = "https://raw.githubusercontent.com/$($LV_REMOTE -replace '\.git$', '')/$LV_BRANCH/utils/installer/install.ps1"
Write-Host "Installing LunarVim from $LV_REMOTE ($LV_BRANCH)..."
$installer = (Invoke-WebRequest -Uri $url).Content
Invoke-Expression $installer
