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

echo "==> Step 7: install Pi"

if command -v pi >/dev/null 2>&1; then
  echo "    pi already installed, skipping"
else
  echo "    installing Pi"
  curl -fsSL https://pi.dev/install.sh | sh
fi

if ! command -v pi >/dev/null 2>&1; then
  echo "ERROR: Pi was installed but 'pi' is not available in PATH."
  echo "       Open a new shell and verify the Pi installation."
  exit 1
fi

echo "    $(pi --version)"

echo "==> Step 8: configure Zsh as login shell"

ZSH="$(command -v zsh)"

if [ -z "$ZSH" ]; then
  echo "ERROR: zsh was not found after Home Manager activation"
  exit 1
fi

CURRENT_SHELL="$(getent passwd "$USER" | cut -d: -f7)"

if [ "$CURRENT_SHELL" = "$ZSH" ]; then
  echo "    login shell already set to $ZSH"
else
  if ! grep -Fxq "$ZSH" /etc/shells; then
    echo "    adding $ZSH to /etc/shells"

    if ! command -v sudo >/dev/null 2>&1; then
      echo "ERROR: sudo is required to add zsh to /etc/shells"
      exit 1
    fi

    printf '%s\n' "$ZSH" | sudo tee -a /etc/shells >/dev/null
  fi

  echo "    changing login shell: $CURRENT_SHELL -> $ZSH"
  chsh -s "$ZSH"
fi

echo
echo "==> Done."
echo "    Use ./rebuild.sh for future changes."
