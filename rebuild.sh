#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

ln -sfn "$DIR" "$HOME/.dotfiles"

exec nix --extra-experimental-features "nix-command flakes" \
  run home-manager/release-26.05 -- \
  switch --flake "$HOME/.dotfiles"
