#!/bin/bash

# set GITHUB_USER to your github username if you want to use your own dotfiles
if [ -z "$GITHUB_USER" ]; then
    GITHUB_USER="jukrb0x"
fi
# to run this script, run the following command:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/jukrb0x/dotfiles/main/setup.sh)"
# or use wget:
#   /bin/bash -c "$(wget -O- https://raw.githubusercontent.com/jukrb0x/dotfiles/main/setup.sh)"
# you can set GITHUB_USER to your github username if you want to use your own dotfiles:
#   /GITHUB_USER=your_github_username bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/jukrb0x/dotfiles/main/setup.sh)"

# Colorful echo
# https://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux
#    .---------- constant part!
#    vvvv vvvv-- the code from above
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[0;33m'
COLOR_GREEN='\033[0;32m'
COLOR_NC='\033[0m' # No Color

echo "========================"
echo " Dev environment setup"
echo -e " ${COLOR_GREEN}$GITHUB_USER${COLOR_NC}'s dotfiles"
echo "========================"
echo "Target machine: $(uname -a)"
echo ""
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
echo "Chezmoi will handle all the dotfiles, nerd fonts, and homebrew packages."
echo ""
echo -e "${COLOR_YELLOW}WARNING${COLOR_NC}: This script will overwrite your existing dotfiles"
echo "         Please backup your dotfiles before running this script"
echo ""
echo "> GitHub: https://github.com/$GITHUB_USER/dotfiles"
echo ""

# let /bin/bash -c can read stdin 'return' key
# https://stackoverflow.com/questions/226703/how-do-i-prompt-for-yes-no-cancel-input-in-a-linux-shell-script
while true; do
    read -p "Press return to continue setup, other keys to exit: " -n 1 -s yn
    if [ -z "$yn" ]; then
        echo ""
        break
    else
        echo ""
        echo "Exiting..."
        exit 0
    fi
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
echo "This will overwrite your existing dotfiles, and install homebrew packages."
chezmoi init --apply $GITHUB_USER

echo "Dev environment setup complete."
