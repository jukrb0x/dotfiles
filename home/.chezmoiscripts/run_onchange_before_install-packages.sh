#!/bin/bash

# chezmoi source-path
chezmoi_source_path="$(chezmoi source-path)"

echo "Executing: brew bundle install --file=\"$chezmoi_source_path/../Brewfile\""
brew bundle install --file="$chezmoi_source_path/../Brewfile"