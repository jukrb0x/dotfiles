#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
brewfile="$repo_root/packages/Brewfile.optional"

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is unavailable. Run the Linux bootstrap first." >&2
  exit 1
fi

brew bundle --file="$brewfile" install
