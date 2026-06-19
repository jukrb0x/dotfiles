#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
brewfiles=(
  "$repo_root/packages/Brewfile.toolchains"
  "$repo_root/packages/Brewfile.linux.toolchains"
)

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is unavailable. Run the Linux bootstrap first." >&2
  exit 1
fi

for brewfile in "${brewfiles[@]}"; do
  brew bundle --file="$brewfile" install
done

if command -v rustup-init >/dev/null 2>&1 && ! command -v rustup >/dev/null 2>&1; then
  rustup-init -y --no-modify-path
fi

echo "Installing LunarVim with the official Linux/macOS installer..."
LV_BRANCH='release-1.4/neovim-0.9' bash <(curl -fsSL https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.4/neovim-0.9/utils/installer/install.sh) --no-install-dependencies
