@{
    # Optional WinGet-managed apps/tools, ordered by setup dependency and daily workflow.
    # Required dotfiles dependencies live in packages/windows-winget-required.psd1 and
    # are synchronized by chezmoi apply.
    Apps = @(
        # Foundation extras
        @{ Id = "GitHub.cli" }
        @{ Id = "Nushell.Nushell" }

        # Secrets
        @{ Id = "AgileBits.1Password" }

        # Internet Browsers
        @{ Id = "Google.Chrome" }
        @{ Id = "Vivaldi.Vivaldi" }
        @{ Id = "Brave.Brave" }

        # System utilities
        @{ Id = "7zip.7zip" }
        @{ Id = "GeekUninstaller.GeekUninstaller" }
        @{ Id = "voidtools.Everything" }

        # Editors and notes
        @{ Id = "Microsoft.VisualStudioCode" }
        @{ Id = "Notion.Notion" }
        @{ Id = "Appest.Dida" }
        @{ Id = "Obsidian.Obsidian" }

        # Terminals
        @{ Id = "Microsoft.WindowsTerminal" }
        @{ Id = "Eugeny.Tabby" }

        # Optional command-line tools with clear WinGet packages
        @{ Id = "aristocratos.btop4win" }
        @{ Id = "bootandy.dust" }
        @{ Id = "dandavison.delta" }
        @{ Id = "eza-community.eza" }
        @{ Id = "JesseDuffield.lazygit" }
        @{ Id = "muesli.duf" }
        @{ Id = "OpenAI.Codex" }
        @{ Id = "tldr-pages.tlrc" }

        # AI apps
        @{ PackageName = "Codex"; Source = "msstore"; Name = "Codex app" }

        # Developer tools
        @{ Id = "Kitware.CMake" }
        @{ Id = "Fastfetch-cli.Fastfetch" }
        @{ Id = "sxyazi.yazi" }
        @{ Id = "Fork.Fork" }
        @{ Id = "GitHub.GitHubDesktop" }

        # IDEs
        @{ Id = "JetBrains.Toolbox" }
        @{ Id = "Anysphere.Cursor" }

        # Games
        @{ Id = "Valve.Steam" }
    )
}
