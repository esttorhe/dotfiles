<!-- ABOUTME: Operate and recover the personal Mac's conservative Multica branch reaper. -->
<!-- ABOUTME: Document ownership evidence, dry-run review, launchd installation, and real-system tests. -->

This user-level tool discovers `local_directory` resources in every workspace
reported by `multica daemon status`, selects this daemon's `worktree` resources,
and audits their `agent/*` branches. No repository list is stored. Python 3.9+
and authenticated `multica` and `git` CLIs must be available without a shell
startup file. It never changes daemon configuration or visits the `.repos` cache.

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
Deletion additionally requires ancestry in the live `origin` default tip, or
an exact live remote tip match for the configured upstream or same-named branch.
Remote-tracking refs alone are insufficient. No fetch occurs, including during
dry runs. If the live default commit is unavailable locally or the remote cannot
be verified, retention is the safe outcome. Local-only merges not present in the
live remote default are retained unless the branch itself is pushed.

`done_unpushed` has its own count and commit subjects; `remote_unverified` is
reported separately. A missing default object causes the log to include the full
branch history because a unique range cannot be proven. Every branch receives an
action or skip reason. Audit output is append-only JSON Lines, with UTC timestamps,
in `~/Library/Logs/multica-reaper/audit.jsonl`. Logs and recovery bundles are kept
until explicitly archived by the owner; no automatic retention deletion runs.

Existing directories and locked worktrees are retained, even when clean.
`git worktree prune --dry-run --verbose --expire=now` runs per repo. Real pruning
is allowed only when **every** proposed registration belongs to a verified,
missing, unlocked worktree of an eligible done branch. One unknown/non-done
candidate prevents that repo's entire pruning pass; branches still registered
after pruning are retained. No worktree directory is deleted.

Before applying a deletion, status, ownership, and preservation are rechecked.
A recovery bundle preserves both refs and their reachable history. Branch and
ownership refs are deleted together in a Git transaction guarded by their exact
old OIDs; concurrent tip changes abort deletion. A file lock prevents overlapping
reaper runs. Git does not provide a transaction spanning Multica status, remote
refs, and worktree registration: these can change after checks. Consequently
apply should run while the daemon is idle; existing directories are never removed,
and bundles provide recovery even if an issue is reopened during that window.

## Install and check on macOS

After merging, apply only these targets from chezmoi (review `chezmoi diff` first):

```sh
mkdir -p "$HOME/Library/Logs/multica-reaper"
chezmoi apply "$HOME/.local/share/multica-reaper" \
  "$HOME/Library/LaunchAgents/com.esttorhe.multica-reaper.plist"
plutil -lint "$HOME/Library/LaunchAgents/com.esttorhe.multica-reaper.plist"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.esttorhe.multica-reaper.plist"
launchctl print "gui/$(id -u)/com.esttorhe.multica-reaper"
tail -n 30 "$HOME/Library/Logs/multica-reaper/audit.jsonl"
```

The plist runs once at load and every hour in **explicit dry-run mode**. It sets
HOME, PATH and the working directory rather than relying on shell initialization.
The audit's final `summary` must have `errors: 0`; launchctl should report last exit
code 0. stdout and stderr also live in the same log directory. Bootstrap is needed
once per login domain; inspect an already loaded job instead of loading it twice.
If the daemon is stopped or this CLI profile resolves a different daemon, the job
logs the failure and exits nonzero without touching Git refs. After a rebuild,
update the plist's daemon UUID to the one verified by `multica daemon status`.

Do not enable deletion until Esteban has reviewed a real dry-run report. To make
a deliberate one-off apply afterward, while the daemon is idle:

```sh
python3 "$HOME/.local/share/multica-reaper/reaper.py" \
  --daemon-id 01a0b3e7-caf5-74c2-8c1e-39788fb67724 --apply
```

Scheduling apply requires an explicit change of the source plist's `--dry-run`
argument to `--apply`, followed by applying and reloading the job. Installation
does not silently switch modes after a report has been generated.

## Stop and rollback

```sh
launchctl bootout "gui/$(id -u)/com.esttorhe.multica-reaper"
```

This stops only this job; it does not stop either Multica daemon. Remove the
reaper's plist after stopping if it must not start at next login. The deployment
adds the reaper directory, its plist and its log directory; it overwrites no
existing user files on first installation. Back up these targets before any
subsequent replacement. To undo a deletion, use the bundle and branch named in
the audit (do not force over an existing branch):

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
