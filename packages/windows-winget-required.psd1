@{
    # WinGet packages required for managed Windows dotfiles to work.
    Packages = @(
        @{ Id = "Git.Git" }
        @{ Id = "Microsoft.PowerShell"; InstallerType = "wix" }
        @{ Id = "twpayne.chezmoi" }
        @{ Id = "Nushell.Nushell" }

        # Terminal multiplexers
        @{ Id = "marlocarlo.psmux" }

        @{ Id = "Neovim.Neovim" }
        @{ Id = "Starship.Starship" }
        @{ Id = "ajeetdsouza.zoxide" }
        @{ Id = "BurntSushi.ripgrep.MSVC" }
        @{ Id = "MSYS2.MSYS2" }
    )
}
