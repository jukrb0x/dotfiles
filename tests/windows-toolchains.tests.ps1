#Requires -Version 7.1
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot "scripts\install-windows-toolchains.ps1"
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
    -Pattern 'tree-sitter\.tree-sitter-cli@0\.26' `
    -Message "tree-sitter CLI should be installed through WinGet with a 0.26 version prefix."

Assert-Match `
    -Text $script `
    -Pattern 'codex/nvim-012-modern-treesitter' `
    -Message "LunarVim should install from the modern Neovim 0.12 branch."

if ($script -match 'Install-TreeSitterCli|tree-sitter-cli-windows-x64|Invoke-WebRequest.+tree-sitter') {
    throw "tree-sitter CLI should not be installed by a hand-rolled download helper."
}

Write-Host "windows-toolchains tests passed."
