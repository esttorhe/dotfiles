# Multica CLI version policy

The Brewfile invokes `scripts/pin-multica.sh` before resolving the unversioned
`multica-ai/tap/multica` entry. This also runs when tools evaluate the Brewfile
for checks or listing. Homebrew Bundle has no exact-version option for this
formula. The script installs 0.4.44 from a checked-in formula, then pins its keg.
Rebuilds need both the Brewfile and its sibling script/formula files.

`multica.rb` is the upstream formula from commit
`14fa5c7336ba8e471bc29d6aeced05309538a45f` of `multica-ai/homebrew-tap`.
It contains versioned release URLs and per-platform SHA-256 checksums. During
installation the script backs up the upstream formula under
`~/.local/state/multica-pin/rollback.*`, temporarily substitutes this snapshot,
and restores the upstream formula on exit. Automatic update and cleanup are
disabled for this operation. Existing 0.5.0 kegs are retained.

Homebrew's pin command selects the newest installed keg. After calling it, the
script corrects the pin symlink to 0.4.44, so retaining 0.5.0 cannot select the
wrong version. Run `bash scripts/test-multica-pin.sh` to check the actual machine.
If the desired keg already exists but another version is linked, the script
fails without silently changing the selection; review that state explicitly.

The pin blocks normal Homebrew upgrades and Brewfile evaluation recreates it.
It is not protection against explicit unpin/reinstall, direct binary replacement,
`multica update`, a manual latest-release installer, or Desktop's managed CLI
fallback. Explicit cleanup can remove a retained rollback keg.

Desktop's managed `updater-preferences.json` sets `automaticUpdates` to false.
In Desktop 0.5.0 this is read at startup, so writing the file does not change
the current process's cached setting. The setting gates future automatic checks;
it does not disable manual checks or install-on-quit for an existing download.
Handle those and the Desktop bundle downgrade in a separate maintenance window.

To restore CLI 0.5.0 while its keg remains: disable the Brewfile's pin invocation,
run `brew unpin multica`, `brew unlink multica`, then `brew link multica` and
verify `multica --version`. Homebrew link selects the newest installed keg.
This does not stop or replace Desktop's bundled daemon.
