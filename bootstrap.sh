#!/usr/bin/env bash
# Takes a fresh Linux system from nothing to a built Home Manager config.
# Run this once. After it finishes, use ./rebuild.sh for every later change.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

echo "==> Step 1: Nix"

if command -v nix >/dev/null 2>&1; then
  echo "    nix already installed, skipping"
else
  echo "    Nix is not installed."
  echo "    Install Nix first, then run this script again."
  exit 1
fi

echo "==> Step 2: configure Nix flakes"

NIX_CONFIG_DIR="$HOME/.config/nix"
NIX_CONFIG_FILE="$NIX_CONFIG_DIR/nix.conf"

mkdir -p "$NIX_CONFIG_DIR"

if [ -f "$NIX_CONFIG_FILE" ] && \
  grep -qE '^[[:space:]]*experimental-features[[:space:]]*=.*\bflakes\b' "$NIX_CONFIG_FILE"; then
  echo "    flakes already enabled"
else
  echo "    enabling nix-command and flakes"

  if [ -f "$NIX_CONFIG_FILE" ]; then
    printf '\n%s\n' \
      'experimental-features = nix-command flakes' \
      >> "$NIX_CONFIG_FILE"
  else
    printf '%s\n' \
      'experimental-features = nix-command flakes' \
      > "$NIX_CONFIG_FILE"
  fi
fi

echo "==> Step 3: symlink this repo to ~/.dotfiles"

ln -sfn "$DIR" "$HOME/.dotfiles"

echo "==> Step 4: personalize the configured username"

REAL_USER="$(whoami)"

FLAKE_USER="$(
  sed -nE \
    's/^[[:space:]]*user = "([^"]+)";.*/\1/p' \
    "$DIR/flake.nix" |
    head -n1
)"

if [ -z "$FLAKE_USER" ]; then
  echo "ERROR: Could not find 'user = \"...\";' in flake.nix"
  exit 1
fi

if [ "$FLAKE_USER" != "$REAL_USER" ]; then
  echo "    updating username: $FLAKE_USER -> $REAL_USER"

  sed -i \
    -E "s/^[[:space:]]*user = \"[^\"]+\";/      user = \"$REAL_USER\";/" \
    "$DIR/flake.nix"
else
  echo "    username already set to $REAL_USER"
fi

echo "==> Step 5: build Home Manager configuration"

nix build \
  "$DIR#homeConfigurations.$REAL_USER.activationPackage"

echo "==> Step 6: activate Home Manager configuration"

nix run home-manager/release-26.05 -- \
  switch --flake "$DIR#$REAL_USER"

echo
echo "==> Done."
echo "    Use ./rebuild.sh for future changes."
