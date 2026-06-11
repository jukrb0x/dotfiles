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
    if ($LASTEXITCODE -ne 0) {
        throw "winget install failed for $Id with exit code $LASTEXITCODE"
    }
}

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

$BootstrapPackages = @(
    "Git.Git",
    "Microsoft.PowerShell",
    "twpayne.chezmoi"
)

foreach ($package in $BootstrapPackages) {
    Install-WinGetPackage $package
}

Write-Host "Bootstrap complete. Open PowerShell 7, then run:"
Write-Host "  chezmoi init https://github.com/jukrb0x/dotfiles.git"
Write-Host "  chezmoi apply"
