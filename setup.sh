#!/bin/bash

GITHUB_USER="jukrb0x"
# to run this script, run the following command
#   curl -fsSL https://raw.githubusercontent.com/jukrb0x/dotfiles/main/setup.sh | bash
# or use wget:
#   wget -qO- https://raw.githubusercontent.com/jukrb0x/dotfiles/main/setup.sh | bash

# install homebrew
# xcode command line tools will be installed automatically if not installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# install chezmoi and clone dotfiles
brew install chezmoi
chezmoi init --apply $GITHUB_USER

# if ~/.local/bin/lvim not exist, install LunarVim:
if [ ! -f ~/.local/bin/lvim ]; then
  # install lunarvim
  LV_BRANCH='release-1.3/neovim-0.9' /bin/bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.3/neovim-0.9/utils/installer/install.sh)
else
  echo "LunarVim already installed"
fi
