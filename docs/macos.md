# macOS

macOS setup is split into three layers:

- bootstrap: install the minimum tools needed to initialize chezmoi
- required state: apply managed dotfiles and required Homebrew packages
- optional setup: install apps, fonts, and toolchains by explicit command

`bootstrap/macos.sh` is intentionally conservative. It installs Homebrew when
missing, installs chezmoi when missing, runs `chezmoi init`, and stops before
applying changes.

## Bootstrap

Fresh machines and existing machines use the same bootstrap command:

```shell
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/jukrb0x/dotfiles/main/bootstrap/macos.sh)"
```

To initialize from a fork or private remote:

```shell
DOTFILES_REPO_URL=https://github.com/you/dotfiles.git /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/jukrb0x/dotfiles/main/bootstrap/macos.sh)"
```

The bootstrap does not run `chezmoi apply` and does not use
`chezmoi init --apply`.

## Existing Machine Migration

On an existing machine, review before changing anything:

```shell
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/jukrb0x/dotfiles/main/bootstrap/macos.sh)"
chezmoi diff
```

Back up any local files that would be replaced or materially changed. Useful
checks include:

```shell
chezmoi diff
chezmoi unmanaged
```

After reviewing the diff and making backups, apply:

```shell
chezmoi apply
```

Do not run `chezmoi init --apply` on an existing machine. The bootstrap/init,
diff, backup, apply sequence keeps local-only files and machine-specific
settings visible before they are touched.

## Daily Maintenance

Preview local source changes:

```shell
chezmoi diff
```

Apply local source changes:

```shell
chezmoi apply
```

Pull the latest repo changes and apply them:

```shell
chezmoi update
```

Open the source repo:

```shell
chezmoi cd
```

## Required Packages

Required macOS packages live in:

- `packages/Brewfile.required`
- `packages/Brewfile.macos.required`

During `chezmoi apply`, the macOS chezmoi onchange script checks that required
Homebrew packages are present and runs:

```shell
brew bundle install --file=packages/Brewfile.required
brew bundle install --file=packages/Brewfile.macos.required
```

This required layer is for tools the managed dotfiles need in order to work.
Use official Homebrew Brewfiles and `brew bundle` for macOS package management;
do not add custom macOS package text lists.

## Optional Setup

Optional setup is explicit and can be run after required state is applied.

Install optional apps:

```shell
chezmoi cd
./scripts/install-macos-apps.sh
```

Install optional fonts:

```shell
chezmoi cd
./scripts/install-macos-fonts.sh
```

Install optional toolchains:

```shell
chezmoi cd
./scripts/install-macos-toolchains.sh
```

These commands use:

- `packages/Brewfile.optional`
- `packages/Brewfile.macos.optional`
- `packages/Brewfile.fonts`
- `packages/Brewfile.toolchains`
- `packages/Brewfile.macos.toolchains`

## Local Private Config

Keep private, account-specific, or machine-specific settings out of managed
dotfiles. Use local include and hook files instead:

- `~/.gitconfig.local`: private Git identity, signing, credentials, and
  account-specific includes
- `~/.zshrc.local.pre`: zsh settings that must load before the managed zsh
  configuration
- `~/.zshrc.local`: local aliases, PATH additions, shell functions, and
  machine-only environment settings
- `~/.zprofile.local`: login-shell environment, local Homebrew or toolchain
  setup, and machine-specific profile exports

These files are intentionally not managed by this repo.

## External Archives

External shell assets can use chezmoi externals, but they are opt-in. Keep the
default off on existing machines so `chezmoi diff` and `chezmoi apply` do not
depend on GitHub archive downloads.

To let chezmoi manage shell externals on a machine, add this to that machine's
chezmoi config:

```toml
[data]
manageShellExternals = true
```

When enabled, Powerlevel10k follows the latest upstream branch archive instead
of doing a GitHub latest-release lookup during template rendering.

Fonts are not managed as chezmoi externals. Install them explicitly with
`./scripts/install-macos-fonts.sh`, which uses `packages/Brewfile.fonts`.

`setup.sh` is legacy only. Use `bootstrap/macos.sh`, `chezmoi apply`, and the
explicit optional setup scripts for current macOS setup.
