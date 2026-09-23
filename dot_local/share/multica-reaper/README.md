<!-- ABOUTME: Operate and recover the personal Mac's conservative Multica branch reaper. -->
<!-- ABOUTME: Document ownership evidence, dry-run review, launchd installation, and real-system tests. -->

This user-level tool discovers `local_directory` resources in every workspace
reported by `multica --profile <profile> daemon status`, selects this daemon's `worktree` resources,
and audits their `agent/*` branches. No repository list is stored. Python 3.9+
and authenticated `multica` and `git` CLIs must be available without a shell
startup file. The required `--profile` is forwarded on every CLI call, including
issue status rechecks. `--multica-bin` selects the executable independently of PATH.
Explicit profile calls run from HOME with inherited `MULTICA_*` overrides removed,
so a managed task's environment or working directory cannot redirect the profile.
It never changes daemon configuration or visits the `.repos` cache.

## Safety contract

Ownership follows [upstream local_worktree.go at 90e0bdf](https://github.com/multica-ai/multica/blob/90e0bdf830436b3981b32a7017e1c18d41c7cdea/server/internal/daemon/execenv/local_worktree.go):
`refs/multica/local-state/<branch>` is a commit with a snapshot parent, a second
parent recording the branch checkpoint, and `Multica-Workspace`, `Multica-Agent`,
and `Multica-Conversation` trailers. For issue tasks, the conversation is the
issue UUID. The checkpoint must still be an ancestor of the branch. Chat-owned,
missing, malformed, ambiguous, or stale records are retained. Branch names never
supply an issue ID.

Only exact `status: done` qualifies, read through `multica issue get` in the
record's workspace. `cancelled` is counted separately and always retained.
Deletion first checks ancestry in the live `origin` default tip, then an exact
live remote tip match for the configured upstream or same-named branch.
Remote-tracking refs alone are insufficient. No fetch occurs, including during
dry runs.

Only a `done_unpushed` result is eligible for these additional rules, in order:

1. `content_equal`: `git diff --quiet <default>...<tip>` reports no changes.
   This compares the merge-base to the branch tip, including agent changes that
   net to zero. It does not compare the two tip trees.
2. `daemon_only`: every commit in `<default>..<tip>` has exactly one parent and
   its full message, with trailing whitespace stripped, exactly matches one of:
   - `chore(agent): baseline — the task worktree started here`
   - `chore(agent): baseline — uncommitted work from the local directory`
   - `chore(agent): uncommitted work from the local directory since the previous turn`
   - `chore(agent): uncommitted changes from task`

Author identity is irrelevant. Additional text, a message body, or a merge commit
disqualifies Rule 2. Rule 1 takes precedence. Both require the live remote default
OID to exist locally; neither applies to `remote_unverified`. A branch containing
other unique work remains `KEEP_UNIQUE_WORK`.

`content_equal` and `daemon_only` have separate summary counts; they are not also
counted as `done_unpushed`. Retained `done_unpushed` branches log commit subjects;
`remote_unverified` is reported separately. A missing default object causes the
log to include the full branch history because a unique range cannot be proven.
Every branch receives an action or skip reason. Audit output is append-only JSON
Lines, with UTC timestamps, in `~/Library/Logs/multica-reaper/audit.jsonl`.

On every run, recovery `backups/*.bundle` files older than 30 days by mtime expire,
regardless of deletion reason. Apply logs each removal as `bundle_expired`;
dry-run logs `would_expire` and removes nothing. Audit logs do not expire.
After expiry, content unique to a daemon-only bundle is no longer recoverable
from that bundle, including snapshots of the owner's uncommitted work.

Existing directories and locked worktrees are retained, even when clean.
`git worktree prune --dry-run --verbose --expire=now` runs per repo. Real pruning
is allowed only when **every** proposed registration belongs to a verified,
missing, unlocked worktree of an eligible done branch. One unknown/non-done
candidate prevents that repo's entire pruning pass; branches still registered
after pruning are retained. No worktree directory is deleted.

Before applying a deletion, status, ownership, and preservation are rechecked.
Both additional rules are re-evaluated against the current tip before deletion;
a moved tip aborts. A recovery bundle in `backups/` preserves both refs and their
reachable history and must pass `git bundle verify` before deletion. Verification
failure keeps the branch and produces an error. For the additional rules,
`backup` and `deleted` entries include the bundle path, unique commit subjects,
and `git diff --stat <default>...<tip>`. Branch and
ownership refs are deleted together in a Git transaction guarded by their exact
old OIDs; concurrent tip changes abort deletion. A file lock prevents overlapping
reaper runs. Git does not provide a transaction spanning Multica status, remote
refs, and worktree registration: these can change after checks. Consequently
apply should run while the daemon is idle; existing directories are never removed,
and bundles provide recovery even if an issue is reopened during that window.

## Install and check on macOS

For this update to an already installed hourly job, run `chezmoi update` after
merging. Confirm the next hourly run's `audit.jsonl` contains `content_equal`
or `daemon_only` reasons when eligible branches exist, and `errors: 0` in its
summary.

After merging, apply only these targets from chezmoi (review `chezmoi diff` first):

```sh
mkdir -p "$HOME/Library/Logs/multica-reaper"
chezmoi apply "$HOME/.local/share/multica-reaper" \
  "$HOME/Library/LaunchAgents/com.esttorhe.multica-reaper.plist"
"/Applications/Multica.app/Contents/Resources/app.asar.unpacked/resources/bin/multica" \
  --profile desktop-garage-multica.tail90165f.ts.net daemon status --output json
plutil -lint "$HOME/Library/LaunchAgents/com.esttorhe.multica-reaper.plist"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.esttorhe.multica-reaper.plist"
launchctl print "gui/$(id -u)/com.esttorhe.multica-reaper"
tail -n 30 "$HOME/Library/Logs/multica-reaper/audit.jsonl"
```

For an already loaded job, reload only the reaper after applying its files:

```sh
launchctl bootout "gui/$(id -u)/com.esttorhe.multica-reaper"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.esttorhe.multica-reaper.plist"
launchctl kickstart "gui/$(id -u)/com.esttorhe.multica-reaper"
```

The plist selects `desktop-garage-multica.tail90165f.ts.net` and the Desktop app's
bundled CLI explicitly. Homebrew 0.4.44 can read this profile's daemon status,
but the bundled 0.5.1 CLI matches the running 0.5.1 daemon. Check both the profile
and daemon UUID before changing these settings; there is no default-profile fallback.

The plist runs once at load and every hour in **explicit apply mode**, matching
Esteban’s approved scheduled-reaping decision. It sets
HOME, PATH and the working directory rather than relying on shell initialization.
The audit's final `summary` must have `errors: 0`; launchctl should report last exit
code 0. stdout and stderr also live in the same log directory. Bootstrap is needed
once per login domain; inspect an already loaded job instead of loading it twice.
If the daemon is stopped or this CLI profile resolves a different daemon, the job
logs the failure and exits nonzero without touching Git refs. After a rebuild,
update the plist's daemon UUID to the one verified by the profile-specific daemon status command above.

To review a one-off dry-run report without deleting refs:

```sh
python3 "$HOME/.local/share/multica-reaper/reaper.py" \
  --profile desktop-garage-multica.tail90165f.ts.net \
  --multica-bin "/Applications/Multica.app/Contents/Resources/app.asar.unpacked/resources/bin/multica" \
  --daemon-id 01a0b3e7-caf5-74c2-8c1e-39788fb67724 --dry-run
```

To switch the schedule back to dry-run, back up the source and installed plists,
change the source plist's `--apply` argument to `--dry-run`, then apply the plist
and reload only the reaper using the commands above. Keep the source change so
a later chezmoi update preserves the selected mode.

## Stop and rollback

```sh
launchctl bootout "gui/$(id -u)/com.esttorhe.multica-reaper"
```

The launchd label is independent of the selected CLI profile. This stops only this job; it does not stop either Multica daemon. Remove the
reaper's plist after stopping if it must not start at next login. The deployment
adds the reaper directory, its plist and its log directory; it overwrites no
existing user files on first installation. Back up these targets before any
subsequent replacement. To roll back a profile or binary change, boot out only
the reaper, restore its backed-up files and plist, then bootstrap that plist.
Do not stop or reconfigure the Desktop daemon to roll back the reaper.
To undo a deletion, use the bundle and branch named in
the audit before its 30-day expiry (do not force over an existing branch):

```sh
git -C /path/to/repo fetch /path/from/audit.bundle \
  refs/heads/agent/name/issue:refs/heads/agent/name/issue \
  refs/multica/local-state/agent/name/issue:refs/multica/local-state/agent/name/issue
```

Pruning removes only registrations for absent directories; restored branches can
be checked out again with `git worktree add` if needed.

## Validation

The tests use actual disposable Git repositories, local bare remotes and
read-only calls to the live Multica CLI. No mock CLI, fake issue database, or
production test mode exists. Supply a workspace containing an existing `done`,
`in_progress`, and `cancelled` issue; tests never mutate these issues. Git commits
use the configured human identity. With pytest and pre-commit installed:

```sh
REAPER_TEST_WORKSPACE=afc3f3a2-107a-46fb-9e6b-64f73b92c8e8 \
  python3 -m pytest -q dot_local/share/multica-reaper
pre-commit run --all-files
```

Coverage includes the required deletion/retention matrix, missing and invalid
ownership, unrelated checkpoint history, failed issue lookup, cancelled issues,
stale remote tracking refs, unreachable remotes, existing/locked/missing
worktrees, mixed unsafe prune candidates, dry-run immutability and recovery from
bundles. Capture a real scheduled run's audit separately for the handoff.
