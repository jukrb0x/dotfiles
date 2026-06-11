#Requires -Version 7.1
$ErrorActionPreference = "Stop"

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

    Write-Host "Installing $name from $source..."

    $arguments = @("install")
    $arguments += @("--id", $id)
    $arguments += @(
        "--exact"
        "--source", $source
        "--silent"
        "--disable-interactivity"
        "--accept-source-agreements"
        "--accept-package-agreements"
    )

    winget @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "winget install failed for $id with exit code $LASTEXITCODE"
    }
}
