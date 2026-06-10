#Requires -Version 7.1
$ErrorActionPreference = "Stop"

# WinGet-managed apps/tools, ordered by setup dependency and daily workflow.
$DefaultSource = "winget"
$Apps = @(
    # Foundation
    @{ Id = "Git.Git" },
    @{ Id = "GitHub.cli" },
    @{ Id = "Microsoft.PowerShell" },
    @{ Id = "Nushell.Nushell" },

    # Secrets
    @{ Id = "AgileBits.1Password" },

    # App maintenance
    @{ Id = "GeekUninstaller.GeekUninstaller" },

    # Editors
    @{ Id = "Microsoft.VisualStudioCode" },
    @{ Id = "Neovim.Neovim" },
    @{ Id = "Obsidian.Obsidian" },

    # Terminals
    @{ Id = "Microsoft.WindowsTerminal" },
    @{ Id = "Eugeny.Tabby" },

    # Shell prompt
    @{ Id = "Starship.Starship" },

    # Command-line tools with clear WinGet packages
    @{ Id = "ajeetdsouza.zoxide" },
    @{ Id = "aristocratos.btop4win" },
    @{ Id = "bootandy.dust" },
    @{ Id = "BurntSushi.ripgrep.MSVC" },
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
}
