#!/bin/bash
# ABOUTME: Checks the real Multica pin and verifies repeat runs preserve installed kegs.
# ABOUTME: Captures command output and fails on version, linkage, or idempotence regressions.
set -euo pipefail
trap 'echo "Multica pin test failed at line $LINENO" >&2' ERR
script_dir="$(cd "$(dirname "$0")" && pwd)"
brew_prefix="$(brew --prefix)"
cellar="$(brew --cellar)"
tap_formula="$(brew --repository multica-ai/tap)/Formula/multica.rb"
before="$(shasum -a 256 "$tap_formula")"
rollback_before=""
if [[ -f "$cellar/multica/0.5.0/bin/multica" ]]; then
  rollback_before="$(shasum -a 256 "$cellar/multica/0.5.0/bin/multica")"
fi
for attempt in 1 2; do
  if ! output="$(bash "$script_dir/pin-multica.sh" 2>&1)"; then
    printf 'Pin attempt %s failed:\n%s\n' "$attempt" "$output" >&2
    exit 1
  fi
done
[[ "$("$brew_prefix/bin/multica" --version)" == 'multica 0.4.44 '* ]]
[[ "$(cd "$brew_prefix/var/homebrew/pinned/multica" && pwd -P)" == "$cellar/multica/0.4.44" ]]
[[ "$(brew list --pinned)" == *multica* ]]
[[ "$(shasum -a 256 "$tap_formula")" == "$before" ]]
if [[ -n "$rollback_before" ]]; then
  [[ "$(shasum -a 256 "$cellar/multica/0.5.0/bin/multica")" == "$rollback_before" ]]
fi
echo 'PASS: exact version, pin target, two repeat runs, upstream formula, and retained rollback binary.'
