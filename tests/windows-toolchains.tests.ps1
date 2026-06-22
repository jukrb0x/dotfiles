#Requires -Version 7.1
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot "scripts\install-windows-toolchains.ps1"
$manifestPath = Join-Path $repoRoot "packages\windows-winget-toolchains.psd1"
$script = Get-Content -LiteralPath $scriptPath -Raw

function Assert-Match {
    param(
        [Parameter(Mandatory)] [string] $Text,
        [Parameter(Mandatory)] [string] $Pattern,
        [Parameter(Mandatory)] [string] $Message
    )

    if ($Text -notmatch $Pattern) {
        throw $Message
    }
}

Assert-Match `
    -Text $script `
    -Pattern '\[switch\]\s*\$NoLvim' `
    -Message "install-windows-toolchains.ps1 should expose a -NoLvim switch."

Assert-Match `
    -Text $script `
    -Pattern 'ValueFromRemainingArguments\s*=\s*\$true' `
    -Message "install-windows-toolchains.ps1 should capture remaining args so --no-lvim can be supported."

Assert-Match `
    -Text $script `
    -Pattern '\$RemainingArgs\s+-contains\s+"--no-lvim"' `
    -Message "install-windows-toolchains.ps1 should translate --no-lvim to the NoLvim switch."

Assert-Match `
    -Text $script `
    -Pattern 'if\s*\(\s*-not\s+\$NoLvim\s*\)' `
    -Message "LunarVim installation should be skipped when NoLvim is set."

Assert-Match `
    -Text $script `
    -Pattern 'windows-winget-toolchains\.psd1' `
    -Message "install-windows-toolchains.ps1 should read WinGet toolchains from packages/windows-winget-toolchains.psd1."

if ($script -match 'Schniz\.fnm|astral-sh\.uv|tree-sitter\.tree-sitter-cli') {
    throw "WinGet toolchain package data should not be hardcoded in install-windows-toolchains.ps1."
}

if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Optional Windows WinGet toolchains should live in packages/windows-winget-toolchains.psd1."
}

$manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
$toolchains = @($manifest.Packages)
$treeSitter = @($toolchains | Where-Object { $_.Id -eq "tree-sitter.tree-sitter-cli" })[0]
if (-not $treeSitter) {
    throw "tree-sitter CLI should be listed in the WinGet toolchains manifest."
}

if ($treeSitter.Version -ne "0.26") {
    throw "tree-sitter CLI should keep its 0.26 version prefix in the manifest."
}

Assert-Match `
    -Text $script `
    -Pattern 'codex/nvim-012-modern-treesitter' `
    -Message "LunarVim should install from the modern Neovim 0.12 branch."

if ($script -match 'Install-TreeSitterCli|tree-sitter-cli-windows-x64|Invoke-WebRequest.+tree-sitter') {
    throw "tree-sitter CLI should not be installed by a hand-rolled download helper."
}

Write-Host "windows-toolchains tests passed."
