#Requires -Version 7.1
$ErrorActionPreference = "Stop"

function Install-WinGetPackage {
    param([Parameter(Mandatory)] [string] $Id)

    $arguments = @(
        "install"
        "--id", $Id
        "--exact"
        "--source", "winget"
        "--silent"
        "--disable-interactivity"
        "--accept-source-agreements"
        "--accept-package-agreements"
    )

    winget @arguments
}

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
