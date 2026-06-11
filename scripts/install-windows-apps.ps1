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
# Optional WinGet-managed apps/tools, ordered by setup dependency and daily workflow.
# Required dotfiles dependencies live in packages/windows-winget-required.txt and
# are synchronized by chezmoi apply.
$DefaultSource = "winget"
$Apps = @(
    # Foundation extras
    @{ Id = "GitHub.cli" },
    @{ Id = "Nushell.Nushell" },

    # Secrets
    @{ Id = "AgileBits.1Password" },

    # App maintenance
    @{ Id = "GeekUninstaller.GeekUninstaller" },

    # Editors and notes
    @{ Id = "Microsoft.VisualStudioCode" },
    @{ Id = "Notion.Notion" },
    @{ Id = "Appest.Dida" },
    @{ Id = "Obsidian.Obsidian" },

    # Terminals
    @{ Id = "Microsoft.WindowsTerminal" },
    @{ Id = "Eugeny.Tabby" },

    # Optional command-line tools with clear WinGet packages
    @{ Id = "aristocratos.btop4win" },
    @{ Id = "bootandy.dust" },
    @{ Id = "dandavison.delta" },
    @{ Id = "eza-community.eza" },
    @{ Id = "JesseDuffield.lazygit" },
    @{ Id = "muesli.duf" },
    @{ Id = "tldr-pages.tlrc" },

    # Developer tools
    @{ Id = "Kitware.CMake" },
    @{ Id = "Fastfetch-cli.Fastfetch" },
    @{ Id = "sxyazi.yazi" },

    # IDEs
    @{ Id = "JetBrains.Toolbox" },
    @{ Id = "Anysphere.Cursor" }
)

foreach ($app in $Apps) {
    $id = $app.Id
    $source = if ($app.Source) { $app.Source } else { $DefaultSource }
    $name = if ($app.Name) { $app.Name } else { $id }

    Install-WinGetPackage -Id $id -Source $source -Name $name
}
