<h1>
    <samp>
      dotfiles for macOS<sup><code>ARM</code></sup>
    </samp>
</h1>

This repository is my dotfiles for ARM-based Apple Silicon, managed with `chezmoi`.

What are dotfiles? check [this website](https://dotfiles.github.io/) for more information.

It's still applicable even if you are not using macOS with Apple Silicon, this repository will help you construct your own dotfiles repository on various platforms.

## Features

A single command to enable the following features:

- Manage dotfiles with `chezmoi`
- Automate installation of Homebrew Packages
- LunarVim
- Nerd Font Pack: `Meslo`
- Tmux configuration
- Oh-My-Zsh configuration
- TODO: iTerm2 configuration

## Installation

> [!WARNING]  
> The setup script will install homebrew and chezmoi, and initialize the dotfiles to the home directory. 
> Make sure you have a backup of your dotfiles before running the script. 
> It's always a good idea to check the script before running it.

`setup.sh` will install homebrew and chezmoi to initalize the basic envionment and pull the dotfiles.

use curl to download and run with bash:

```shell
$ /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/jukrb0x/dotfiles/main/setup.sh)"
```

or use wget:

```shell
$ /bin/bash -c "$(wget -O- https://raw.githubusercontent.com/jukrb0x/dotfiles/main/setup.sh)"
```

Afterwards, the chezmoi will run the scripts in `.chezmoiscripts` to install packages via homebrew, you can check `Brewfile` for the list of packages. The [LunarVim](https://github.com/lunarvim/lunarvim) will be installed after the homebrew packages.

Chezmoi externals feature enables to pull other repositories to the home directory, such as tmux and oh-my-zsh configurations, and install a nerd font pack `Meslo` into the system.

## Documentation

- [chezmoi](https://www.chezmoi.io/)

## Extras

Sibling repositories (managed with `yadm`):

- Dotfiles for Windows Subsystem Linux (Ubuntu 20): [dotfiles-wsl-ubuntu](https://github.com/jukrb0x/dotfiles-wsl-ubuntu)
- Dotfiles for macOS 11.4 (intel): [dotfiles-macos-intel](https://github.com/jukrb0x/dotfiles-macos-intel)
