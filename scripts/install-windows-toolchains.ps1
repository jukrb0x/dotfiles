#Requires -Version 7.1
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "lib\WindowsSetup.psm1") -Force -DisableNameChecking

function Install-TreeSitterCli {
    $version = "0.26.9"
    $binDir = Join-Path $HOME ".local\bin"
    $exe = Join-Path $binDir "tree-sitter.exe"

    if (Test-Path $exe) {
        $installedVersion = & $exe --version 2>$null
        if ($installedVersion -match "\b0\.26\.") {
            Write-Host "tree-sitter CLI is already installed: $installedVersion"
            return
        }
    }

    Write-Host "Installing tree-sitter CLI $version..."
    $archive = Join-Path $env:TEMP "tree-sitter-cli-windows-x64-$version.zip"
    $extractDir = Join-Path $env:TEMP "tree-sitter-cli-$version"
    $uri = "https://github.com/tree-sitter/tree-sitter/releases/download/v$version/tree-sitter-cli-windows-x64.zip"

    New-Item -ItemType Directory -Force -Path $binDir | Out-Null
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $extractDir
    Invoke-WebRequest -Uri $uri -OutFile $archive
    Expand-Archive -LiteralPath $archive -DestinationPath $extractDir -Force

    $candidate = Get-ChildItem -Path $extractDir -Recurse -Filter "tree-sitter*.exe" | Select-Object -First 1
    if (-not $candidate) {
        throw "tree-sitter executable was not found in $archive"
    }

    Copy-Item -LiteralPath $candidate.FullName -Destination $exe -Force
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

Install-TreeSitterCli

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

Write-Host "Installing LunarVim from the jukrb0x fork..."
pwsh -c "`$LV_REMOTE='jukrb0x/LunarVim.git'; `$LV_BRANCH='codex/nvim-012-legacy-treesitter'; iwr https://raw.githubusercontent.com/jukrb0x/LunarVim/codex/nvim-012-legacy-treesitter/utils/installer/install.ps1 -UseBasicParsing | iex"
