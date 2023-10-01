#!/bin/bash

echo "========================"
echo "Chezmoi Script: run_onchange_before_install-packages.sh"
echo "========================"
# chezmoi source-path
chezmoi_source_path="$(chezmoi source-path)"

# make sure brew is installed (usually installed by setup.sh)
if [ ! "$(command -v brew)" ]; then
  echo "brew could not be found, installing homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "Executing: brew bundle install --file=\"$chezmoi_source_path/../Brewfile\""
brew bundle install --file="$chezmoi_source_path/../Brewfile"


# this require neovim is installed which should be done by brew bundle
# if ~/.local/bin/lvim not exist, install LunarVim:
if [ ! -f ~/.local/bin/lvim ]; then
  echo "Installing LunarVim"
  # install lunarvim
  LV_BRANCH='release-1.3/neovim-0.9' /bin/bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.3/neovim-0.9/utils/installer/install.sh)
else
  echo "Skipping LunarVim installation, ~/.local/bin/lvim already exists"
fi