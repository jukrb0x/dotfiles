#Requires -Version 7.1
$ErrorActionPreference = "Stop"

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
# Optional language/toolchain managers. Required editor dependencies live in
# packages/*-required.txt and are synchronized by chezmoi apply.
$Toolchains = @(
    "Schniz.fnm",
    "astral-sh.uv",
    "Rustlang.Rustup",
    "GoLang.Go",
    "Oven-sh.Bun"
)

foreach ($toolchain in $Toolchains) {
    Install-WinGetPackage $toolchain
}

& (Join-Path $PSScriptRoot "set-windows-user-path.ps1")

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
    uv python install
}

Write-Host "Installing LunarVim with the official Windows installer..."
pwsh -c "`$LV_BRANCH='release-1.4/neovim-0.9'; iwr https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.4/neovim-0.9/utils/installer/install.ps1 -UseBasicParsing | iex"
