#Requires -Version 7.1
param(
    [switch] $NoLvim,
    [Parameter(ValueFromRemainingArguments = $true)] [string[]] $RemainingArgs
)

$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "lib\WindowsSetup.psm1") -Force -DisableNameChecking

if ($RemainingArgs -contains "--no-lvim") {
    $NoLvim = $true
}

# Optional language/toolchain managers. Required editor dependencies live in
# packages/*-required.txt and are synchronized by chezmoi apply.
$Toolchains = @(
    "Schniz.fnm",
    "astral-sh.uv",
    "Rustlang.Rustup",
    "GoLang.Go",
    "Oven-sh.Bun",
    "tree-sitter.tree-sitter-cli@0.26"
)

foreach ($toolchain in $Toolchains) {
    Install-WinGetPackageSpec -Spec (Parse-WinGetPackageSpec $toolchain)
}

& (Join-Path $PSScriptRoot "set-windows-user-environment.ps1")
& (Join-Path $PSScriptRoot "set-windows-user-path.ps1")

Set-ManagedUserEnvironment -Name "BUN_INSTALL" -Value (Join-Path $HOME ".bun")
Add-ManagedUserPath -Path (Join-Path $HOME ".bun\bin")

if (Get-Command fnm -ErrorAction SilentlyContinue) {
    fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
    fnm install --lts
    fnm default lts-latest
    fnm use lts-latest

    if (Get-Command corepack -ErrorAction SilentlyContinue) {
        corepack enable
        corepack prepare pnpm@latest --activate
    }
}

if (Get-Command rustup -ErrorAction SilentlyContinue) {
    rustup default stable
}

if (Get-Command uv -ErrorAction SilentlyContinue) {
    $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
    $windowsAppsPath = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"
    $pythonIsWindowsAppsAlias = $pythonCommand -and
        $pythonCommand.Source -and
        $pythonCommand.Source.StartsWith($windowsAppsPath, [StringComparison]::OrdinalIgnoreCase)

    if (-not $pythonCommand -or $pythonIsWindowsAppsAlias) {
        uv python install --default
    } else {
        uv python install
    }
}

if (-not $NoLvim) {
    Write-Host "Installing LunarVim from the jukrb0x fork..."
    pwsh -c "`$LV_REMOTE='jukrb0x/LunarVim.git'; `$LV_BRANCH='codex/nvim-012-modern-treesitter'; iwr https://raw.githubusercontent.com/jukrb0x/LunarVim/codex/nvim-012-modern-treesitter/utils/installer/install.ps1 -UseBasicParsing | iex"
} else {
    Write-Host "Skipping LunarVim install."
}
