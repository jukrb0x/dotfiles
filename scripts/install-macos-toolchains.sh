#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
brewfile="$repo_root/Brewfile.toolchains"

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is unavailable. Run bootstrap/macos.sh first." >&2
  exit 1
fi

brew bundle install --file="$brewfile"

if [[ ! -x "$HOME/.local/bin/lvim" ]]; then
  echo "LunarVim is not installed at $HOME/.local/bin/lvim."
  echo "LunarVim installation remains explicit/manual; check the current upstream instructions before installing."
fi
