#!/bin/bash
# ABOUTME: Installs the checksummed Multica 0.4.44 formula and pins its Homebrew keg.
# ABOUTME: Preserves newer kegs and restores the upstream tap formula after installation.
set -euo pipefail
trap 'echo "Multica pin failed at line $LINENO" >&2' ERR
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1
script_dir="$(cd "$(dirname "$0")" && pwd)"
brew_prefix="$(brew --prefix)"
cellar="$(brew --cellar)"
expected="$cellar/multica/0.4.44/bin/multica"
brew tap multica-ai/tap
tap_dir="$(brew --repository multica-ai/tap)"
formula="$tap_dir/Formula/multica.rb"
snapshot="$script_dir/multica-pin/multica.rb"

if [[ ! -x "$expected" ]]; then
  state_dir="$HOME/.local/state/multica-pin"
  mkdir -p "$state_dir"
  backup_dir="$(mktemp -d "$state_dir/rollback.XXXXXX")"
  cp -p "$formula" "$backup_dir/multica.rb"
  trap 'cp -p "$backup_dir/multica.rb" "$formula"' EXIT
  cp "$snapshot" "$formula"
  if [[ -d "$cellar/multica" ]]; then
    brew unlink multica
  fi
  brew install multica-ai/tap/multica
fi

if [[ "$("$brew_prefix/bin/multica" --version 2>/dev/null || true)" != *"0.4.44"* ]]; then
  echo "Multica 0.4.44 must be linked before pinning; refusing to pin another version." >&2
  exit 1
fi
pin="$brew_prefix/var/homebrew/pinned/multica"
if [[ ! -L "$pin" ]]; then
  brew pin multica
fi
# Homebrew pins the newest installed keg; retain 0.5.0 but pin the selected keg.
if [[ "$(cd "$pin" && pwd -P)" != "$cellar/multica/0.4.44" ]]; then
  ln -sfn "$cellar/multica/0.4.44" "$pin"
fi
"$brew_prefix/bin/multica" --version
