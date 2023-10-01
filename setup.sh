#!/bin/bash

GITHUB_USER="jukrb0x"
# to run this script, run the following command:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/jukrb0x/dotfiles/main/setup.sh)"
# or use wget:
#   /bin/bash -c "$(wget -O- https://raw.githubusercontent.com/jukrb0x/dotfiles/main/setup.sh)"

echo "========================"
echo " Dev environment setup"
echo " $GITHUB_USER's dotfiles"
echo "========================"
echo "Target machine: $(uname -a)"
# make sure this is a mac with arm64
if [ "$(uname -a | grep -c "Darwin.*arm64")" -ne 1 ]; then
  echo "This script is made for mac with arm64, exiting"
  exit 1
fi
echo "This script will do the following:"
echo "  1. install homebrew"
echo "  2. install chezmoi"
echo "  3. chezmoi init --apply $GITHUB_USER"
echo ""
echo "WARNING: This script will overwrite your existing dotfiles"
echo "         Please backup your dotfiles before running this script"
echo "GitHub repo: https://github.com/$GITHUB_USER/dotfiles"
echo ""
echo ""

# let /bin/bash -c can read stdin 'return' key
# https://stackoverflow.com/questions/226703/how-do-i-prompt-for-yes-no-cancel-input-in-a-linux-shell-script
while true; do
  read -p "Press return to continue setup, other keys to exit" yn
  case $yn in
    "" ) break;;
    * ) exit;;
  esac
done


# install homebrew
# xcode command line tools will be installed automatically if not installed
if [ ! "$(command -v brew)" ]; then
  echo "brew could not be found, installing homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "homebrew already installed."
fi

# install chezmoi and clone dotfiles
if [ ! "$(command -v chezmoi)" ]; then
  echo "chezmoi could not be found, installing chezmoi with homebrew"
  brew install chezmoi
else
  echo "chezmoi already installed."
fi

echo "Executing: chezmoi init --apply $GITHUB_USER"
chezmoi init --apply $GITHUB_USER
