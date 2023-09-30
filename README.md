<h1>
    <samp>
      dotfiles for macOS<sup><code>ARM</code></sup>
    </samp>
</h1>

This repository is my dotfiles for macOS 12.4 (ARM-based Apple Silicon), managed with `chezmoi`.

What are dotfiles? check [this website](https://dotfiles.github.io/) for more information.

The main goal is making the dotfiles installation easy on a clean OS.

## Installation

> todo: homebrew automation

- homebrew
- zsh + oh-my-zsh
- tmux + oh-my-tmux
- n + yarn
- ranger
- neovim + lunarvim
- pinentry-mac
- pipenv
- bpytop
- [rustup](https://www.rust-lang.org/tools/install)


```sh
$ chezmoi init --apply jukrb0x
```

## Documentation

- [chezmoi](https://www.chezmoi.io/)

## Extras

Sibling repositories (managed with `yadm`):

- Dotfiles for Windows Subsystem Linux (Ubuntu 20): [dotfiles-wsl-ubuntu](https://github.com/jukrb0x/dotfiles-wsl-ubuntu)
- Dotfiles for macOS 11.4 (intel): [dotfiles-macos-intel](https://github.com/jukrb0x/dotfiles-macos-intel)

