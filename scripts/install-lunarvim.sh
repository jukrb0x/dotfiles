#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# This repository-owned manifest is also read by the Windows installer.
source "$script_dir/../packages/lunarvim.env"
export LV_REMOTE LV_BRANCH

case "$(uname -s)" in
  Darwin|Linux) ;;
  *) echo "Use install-lunarvim.ps1 on Windows." >&2; exit 1 ;;
esac
for dependency in curl git nvim make; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    echo "Missing $dependency. Apply required packages first (chezmoi apply)." >&2
    exit 1
  fi
done

installer="$(mktemp)"
trap 'rm -f "$installer"' EXIT
curl -fsSL "https://raw.githubusercontent.com/${LV_REMOTE%.git}/$LV_BRANCH/utils/installer/install.sh" -o "$installer"
echo "Installing LunarVim from $LV_REMOTE ($LV_BRANCH)..."
bash "$installer" "$@"
