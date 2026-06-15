#Requires -Version 7.1
$ErrorActionPreference = "Stop"

function Test-WinGetPackageInstalled {
    param(
        [string] $Id,
        [string] $Name,
        [string] $Source = "winget"
    )

    $arguments = @(
        "list"
        "--exact"
        "--source", $Source
        "--disable-interactivity"
    )

    if ($Id) {
        $arguments += @("--id", $Id)
    } else {
        $arguments += @("--name", $Name)
    }

    winget @arguments | Out-Null
    return $LASTEXITCODE -eq 0
}

function Install-WinGetPackage {
    param(
        [string] $Id,
        [string] $PackageName,
        [string] $Source = "winget",
        [string] $Name = $Id
    )

    $displayName = if ($Name) { $Name } elseif ($PackageName) { $PackageName } else { $Id }

    if (Test-WinGetPackageInstalled -Id $Id -Name $PackageName -Source $Source) {
        Write-Host "$displayName is already installed."
        return
    }

    Write-Host "Installing $displayName from $Source..."

    if ($Id) {
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
    } else {
        $arguments = @(
            "install"
            $PackageName
            "--exact"
            "--source", $Source
            "--silent"
            "--disable-interactivity"
            "--accept-source-agreements"
            "--accept-package-agreements"
        )
    }

    winget @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "winget install failed for $displayName with exit code $LASTEXITCODE"
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
    @{ Id = "voidtools.Everything" },

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
    @{ Id = "OpenAI.Codex" },
    @{ Id = "tldr-pages.tlrc" },

    # AI apps
    @{ PackageName = "Codex"; Source = "msstore"; Name = "Codex app" },

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
    $packageName = $app.PackageName
    $source = if ($app.Source) { $app.Source } else { $DefaultSource }
    $name = if ($app.Name) { $app.Name } elseif ($packageName) { $packageName } else { $id }

    Install-WinGetPackage -Id $id -PackageName $packageName -Source $source -Name $name
}
