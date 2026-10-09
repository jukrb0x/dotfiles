#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
brewfiles=(
  "$repo_root/packages/Brewfile.toolchains"
  "$repo_root/packages/Brewfile.macos.toolchains"
)

no_lvim=false
for argument in "$@"; do
  case "$argument" in
    --no-lvim) no_lvim=true ;;
    *) echo "Usage: $0 [--no-lvim]" >&2; exit 1 ;;
  esac
done

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is unavailable. Run bootstrap/macos.sh first." >&2
  exit 1
fi

for brewfile in "${brewfiles[@]}"; do
  brew bundle install --file="$brewfile"
done

if [[ "$no_lvim" == false ]]; then
  bash "$script_dir/install-lunarvim.sh"
else
  echo "Skipping LunarVim install."
fi
