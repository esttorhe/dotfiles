# ABOUTME: Conservatively reap completed Multica local-directory task branches.
# ABOUTME: Discover live resources, verify ownership and preservation, and audit every decision.
"""Standard-library-only reaper. Read README.md before enabling --apply."""

import argparse
import fcntl
import json
import os
import re
import subprocess
import sys
import uuid
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

STATE_REF = "refs/multica/local-state/"


def delete_refs(repo, branch, tip, oid):
    transaction = (
        f"start\ndelete refs/heads/{branch} {tip}\n"
        f"delete {STATE_REF}{branch} {oid}\nprepare\ncommit\n"
    )
    git(repo, "update-ref", "--no-deref", "--stdin", data=transaction)


class Unsafe(RuntimeError):
    pass


def run(*args, cwd=None, data=None, ok=(0,)):
    env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
    env.update(LC_ALL="C", GIT_TERMINAL_PROMPT="0", GIT_NO_REPLACE_OBJECTS="1")
    try:
        result = subprocess.run(
            args,
            cwd=cwd,
            input=data,
            text=True,
            capture_output=True,
            env=env,
            timeout=60,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise Unsafe(f"{args[0]} failed: {type(exc).__name__}") from exc
    if result.returncode not in ok:
        # Command stderr can contain credential-bearing remote URLs.
        raise Unsafe(f"{args[0]} {args[1]} failed (exit {result.returncode})")
    return result


def git(repo, *args, **kwargs):
    return run("git", "-C", str(repo), *args, **kwargs).stdout.strip()


def cli(*args):
    return json.loads(run("multica", *args, "--output", "json").stdout)


def issue_status(owner):
    workspace, _, issue = owner
    value = cli("--workspace-id", workspace, "issue", "get", issue)
    if value.get("id") != issue or value.get("workspace_id") != workspace:
        raise Unsafe("issue identity mismatch")
    return value["status"]


def ancestor(repo, first, second):
    return (
        run(
            "git",
            "-C",
            str(repo),
            "merge-base",
            "--is-ancestor",
            first,
            second,
            ok=(0, 1),
        ).returncode
        == 0
    )


def record(repo, branch, tip, workspaces):
    ref = STATE_REF + branch
    if not git(repo, "for-each-ref", "--format=%(objectname)", ref):
        raise Unsafe("ownership ref missing")
    if git(repo, "for-each-ref", "--format=%(symref)", ref):
        raise Unsafe("symbolic ownership ref")
    oid = git(repo, "rev-parse", "--verify", ref + "^{commit}")
    parents = git(repo, "show", "-s", "--format=%P", oid).split()
    if len(parents) != 2 or not ancestor(repo, parents[1], tip):
        raise Unsafe("ownership checkpoint absent or no longer an ancestor")
    body = git(repo, "show", "-s", "--format=%B", oid)
    owner = []
    for key in ("Multica-Workspace", "Multica-Agent", "Multica-Conversation"):
        values = re.findall(r"^" + key + r":\s*([^\n]+)$", body, re.MULTILINE)
        if len(values) != 1:
            raise Unsafe("ownership trailers missing or ambiguous")
        value = values[0].strip()
        if str(uuid.UUID(value)) != value:
            raise Unsafe("ownership trailer is not a canonical UUID")
        owner.append(value)
    if owner[0] not in workspaces:
        raise Unsafe("owner workspace is not a discovered resource workspace")
    return oid, tuple(owner)


def worktrees(repo):
    raw = run("git", "-C", str(repo), "worktree", "list", "--porcelain", "-z").stdout
    rows = []
    for block in raw.split("\0\0"):
        row = {}
        for field in block.split("\0"):
            if field:
                key, _, value = field.partition(" ")
                row[key] = value
        if row:
            rows.append(row)
    return rows


def preservation(repo, branch, tip):
    """Consult live remote refs, never stale remote-tracking refs."""
    remotes = git(repo, "remote").splitlines()
    default = None
    errors = []
    if "origin" in remotes:
        try:
            lines = git(repo, "ls-remote", "--symref", "origin", "HEAD").splitlines()
            if any(re.fullmatch(r"ref: refs/heads/\S+\s+HEAD", line) for line in lines):
                for line in lines:
                    if re.fullmatch(r"[0-9a-f]{40,64}\s+HEAD", line):
                        default = line.split()[0]
            if default and ancestor(repo, tip, default):
                return "merged", default
        except Unsafe as exc:
            errors.append(str(exc))
    upstream = git(
        repo,
        "for-each-ref",
        "--format=%(upstream:remotename) %(upstream:remoteref)",
        "refs/heads/" + branch,
    ).split()
    for remote in remotes:
        target = (
            upstream[1]
            if len(upstream) == 2 and upstream[0] == remote
            else "refs/heads/" + branch
        )
        try:
            lines = git(repo, "ls-remote", "--refs", remote, target).splitlines()
            if any(line.split() == [tip, target] for line in lines):
                return "pushed_equal", default
        except Unsafe as exc:
            errors.append(str(exc))
    return ("remote_unverified" if errors else "done_unpushed"), default


class Reaper:
    def __init__(self, state, apply=False):
        self.state = Path(state)
        self.state.mkdir(parents=True, exist_ok=True)
        self.apply = apply
        self.counts = Counter(
            {
                key: 0
                for key in (
                    "merged",
                    "pushed_equal",
                    "done_unpushed",
                    "remote_unverified",
                    "cancelled",
                    "not_done",
                    "unresolvable",
                    "worktree_present_or_locked",
                )
            }
        )
        self.errors = 0

    def log(self, action, reason, **fields):
        entry = dict(
            time=datetime.now(timezone.utc).isoformat(),
            action=action,
            reason=reason,
            **fields,
        )
        line = json.dumps(entry, ensure_ascii=True)
        with (self.state / "audit.jsonl").open("a") as stream:
            stream.write(line + "\n")
            stream.flush()
            os.fsync(stream.fileno())
        print(line, flush=True)

    def discover(self, daemon_id):
        status = cli("daemon", "status")
        if status.get("daemon_id") != daemon_id or status.get("status") != "running":
            raise Unsafe("configured daemon is not running in this CLI profile")
        repos = {}
        for workspace in status["workspaces"]:
            wid = workspace["id"]
            projects = cli("--workspace-id", wid, "project", "list")
            if not isinstance(projects, list):
                raise Unsafe("unexpected project list shape")
            for project in projects:
                resources = cli(
                    "--workspace-id", wid, "project", "resource", "list", project["id"]
                )
                for resource in resources:
                    spec = resource.get("resource_ref", {})
                    if (
                        resource["resource_type"] != "local_directory"
                        or spec.get("daemon_id") != daemon_id
                    ):
                        continue
                    if spec.get("execution_mode") != "worktree":
                        self.log(
                            "skip_resource", "not worktree mode", project=project["id"]
                        )
                        continue
                    path = Path(spec["local_path"]).resolve(strict=True)
                    repos.setdefault(path, set()).add(wid)
        self.log(
            "discovery",
            "live daemon resources",
            workspaces=len(status["workspaces"]),
            repos=len(repos),
        )
        return repos

    def prune(self, repo, eligible):
        preview = run(
            "git",
            "-C",
            str(repo),
            "worktree",
            "prune",
            "--dry-run",
            "--verbose",
            "--expire=now",
        )
        lines = (preview.stdout + preview.stderr).splitlines()
        if not lines:
            self.log("prune", "no stale registrations", repo=str(repo))
            return
        common = Path(
            git(repo, "rev-parse", "--path-format=absolute", "--git-common-dir")
        )
        permitted = True
        for line in lines:
            match = re.fullmatch(r"Removing worktrees/([^/:]+): .+", line)
            path = None
            if match:
                admin = common / "worktrees" / match[1]
                try:
                    path = str(Path((admin / "gitdir").read_text().strip()).parent)
                    permitted = (
                        permitted
                        and not (admin / "locked").exists()
                        and path in eligible
                    )
                except OSError:
                    permitted = False
            else:
                permitted = False
            self.log("prune_candidate", line, repo=str(repo), path=path)
        if not permitted:
            self.log(
                "skip_prune",
                "at least one candidate lacks done/preservation proof",
                repo=str(repo),
            )
        elif self.apply:
            # Never remove an existing directory, even an empty or broken checkout.
            if any(os.path.lexists(path) for path in eligible):
                raise Unsafe("worktree path reappeared before prune")
            output = run(
                "git", "-C", str(repo), "worktree", "prune", "--verbose", "--expire=now"
            )
            self.log(
                "pruned",
                "verified missing done worktrees",
                repo=str(repo),
                output=output.stdout + output.stderr,
            )
        else:
            self.log("would_prune", "verified missing done worktrees", repo=str(repo))

    def repository(self, repo, workspaces):
        repo = Path(repo).resolve(strict=True)
        common = Path(
            git(repo, "rev-parse", "--path-format=absolute", "--git-common-dir")
        )
        if (
            ".repos" in common.parts
            or git(repo, "rev-parse", "--is-bare-repository") != "false"
        ):
            raise Unsafe("daemon bare cache or bare repository is excluded")
        if git(repo, "rev-parse", "--is-shallow-repository") != "false":
            raise Unsafe("shallow repository is excluded")
        if (common / "info/grafts").exists():
            raise Unsafe("repository with ancestry grafts is excluded")
        rows = worktrees(repo)
        branches = git(
            repo,
            "for-each-ref",
            "--format=%(refname) %(objectname) %(symref)",
            "refs/heads/agent/",
        )
        candidates = []
        eligible_paths = set()
        for line in branches.splitlines():
            parts = line.split()
            ref, tip = parts[:2]
            branch = ref.removeprefix("refs/heads/")
            fields = {"repo": str(repo), "branch": branch, "tip": tip}
            try:
                if len(parts) != 2:
                    raise Unsafe("symbolic branch ref")
                oid, owner = record(repo, branch, tip, workspaces)
                status = issue_status(owner)
            except (Unsafe, ValueError, KeyError) as exc:
                self.counts["unresolvable"] += 1
                self.log("keep", "unresolvable", detail=str(exc), **fields)
                continue
            fields.update(issue=owner[2], status=status)
            if status != "done":
                reason = "cancelled" if status == "cancelled" else "not_done"
                self.counts[reason] += 1
                self.log("keep", reason, **fields)
                continue
            reason, default = preservation(repo, branch, tip)
            if reason not in ("merged", "pushed_equal"):
                self.counts[reason] += 1
                revisions = [tip]
                if default:
                    try:
                        git(repo, "cat-file", "-e", default + "^{commit}")
                        revisions.append("^" + default)
                    except Unsafe:
                        pass
                subjects = git(repo, "log", "--format=%h %s", *revisions).splitlines()
                self.log("KEEP_UNIQUE_WORK", reason, commits=subjects, **fields)
                continue
            held = [row for row in rows if row.get("branch") == ref]
            if any("locked" in row or os.path.lexists(row["worktree"]) for row in held):
                self.counts["worktree_present_or_locked"] += 1
                self.log("keep", "worktree_present_or_locked", **fields)
                continue
            self.counts[reason] += 1
            eligible_paths.update(row["worktree"] for row in held)
            candidates.append((branch, tip, oid, owner, fields))
            self.log("candidate", reason, **fields)
        self.prune(repo, eligible_paths)
        for branch, tip, oid, owner, fields in candidates:
            if not self.apply:
                self.log("would_delete", "dry-run; no refs changed", **fields)
                continue
            if any(
                row.get("branch") == "refs/heads/" + branch for row in worktrees(repo)
            ):
                self.log("keep", "worktree registration still exists", **fields)
                continue
            if (
                issue_status(owner) != "done"
                or record(repo, branch, tip, workspaces)[0] != oid
            ):
                raise Unsafe("owner or issue changed before deletion")
            if preservation(repo, branch, tip)[0] not in ("merged", "pushed_equal"):
                raise Unsafe("preservation proof changed before deletion")
            backup = self.state / "backups" / (uuid.uuid4().hex + ".bundle")
            backup.parent.mkdir(exist_ok=True)
            git(
                repo,
                "bundle",
                "create",
                str(backup),
                "refs/heads/" + branch,
                STATE_REF + branch,
            )
            self.log(
                "backup",
                "restore refs with git fetch bundle ref:ref",
                bundle=str(backup),
                **fields,
            )
            # Both old OIDs must still match; failure deletes neither ref.
            delete_refs(repo, branch, tip, oid)
            self.log(
                "deleted",
                "branch and ownership ref atomically removed",
                bundle=str(backup),
                **fields,
            )
        self.log(
            "repository_complete",
            "scan finished",
            repo=str(repo),
            branches=len(branches.splitlines()),
        )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--daemon-id", required=True)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument(
        "--apply",
        action="store_true",
        help="delete only after reviewing the real dry-run report",
    )
    modes.add_argument(
        "--dry-run", action="store_true", help="default; log without changing Git state"
    )
    parser.add_argument(
        "--state-dir", type=Path, default=Path.home() / "Library/Logs/multica-reaper"
    )
    args = parser.parse_args()
    os.umask(0o077)
    reaper = Reaper(args.state_dir, args.apply)
    with (reaper.state / "run.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            reaper.log("skip_run", "another reaper holds the lock")
            return 0
        reaper.log("start", "apply" if args.apply else "dry-run")
        try:
            repos = reaper.discover(args.daemon_id)
            for repo, workspaces in repos.items():
                try:
                    reaper.repository(repo, workspaces)
                except (Unsafe, OSError, ValueError, KeyError) as exc:
                    reaper.errors += 1
                    reaper.log("error", str(exc), repo=str(repo))
        except (Unsafe, OSError, ValueError, KeyError) as exc:
            reaper.errors += 1
            reaper.log("error", str(exc))
        reaper.log(
            "summary", "finished", counts=dict(reaper.counts), errors=reaper.errors
        )
        if reaper.errors:
            print("multica-reaper failed; inspect audit.jsonl", file=sys.stderr)
        return int(bool(reaper.errors))


if __name__ == "__main__":
    sys.exit(main())
