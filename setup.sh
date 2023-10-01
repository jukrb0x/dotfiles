#!/bin/bash

GITHUB_USER="jukrb0x"
# to run this script, run the following command
#   curl -fsSL https://raw.githubusercontent.com/jukrb0x/dotfiles/main/setup.sh | bash
# or use wget:
#   wget -qO- https://raw.githubusercontent.com/jukrb0x/dotfiles/main/setup.sh | bash

# install homebrew
# xcode command line tools will be installed automatically if not installed
if [ ! "$(command -v brew)" ]; then
  echo "brew could not be found, installing homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# install chezmoi and clone dotfiles
if [ ! "$(command -v chezmoi)" ]; then
  echo "chezmoi could not be found, installing chezmoi with homebrew"
  brew install chezmoi
fi

echo "Executing: chezmoi init --apply $GITHUB_USER"
chezmoi init --apply $GITHUB_USER
