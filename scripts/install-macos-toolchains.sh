#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
brewfiles=(
  "$repo_root/packages/Brewfile.toolchains"
  "$repo_root/packages/Brewfile.macos.toolchains"
)

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is unavailable. Run bootstrap/macos.sh first." >&2
  exit 1
fi

for brewfile in "${brewfiles[@]}"; do
  brew bundle install --file="$brewfile"
done

if [[ ! -x "$HOME/.local/bin/lvim" ]]; then
  echo "LunarVim is not installed at $HOME/.local/bin/lvim."
  echo "LunarVim installation remains explicit/manual; check the current upstream instructions before installing."
fi
