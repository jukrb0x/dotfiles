#!/bin/bash

# chezmoi source-path
chezmoi_source_path="$(chezmoi source-path)"

echo "Executing: brew bundle install --file=\"$chezmoi_source_path/../Brewfile\""

# make sure brew is installed (usually installed by setup.sh)
if [ ! "$(command -v brew)" ]; then
  echo "brew could not be found, installing brew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

brew bundle install --file="$chezmoi_source_path/../Brewfile"


# this require neovim is installed which should be done by brew bundle
# if ~/.local/bin/lvim not exist, install LunarVim:
if [ ! -f ~/.local/bin/lvim ]; then
  # install lunarvim
  LV_BRANCH='release-1.3/neovim-0.9' /bin/bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.3/neovim-0.9/utils/installer/install.sh)
else
  echo "LunarVim already installed"
fi