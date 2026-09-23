# ABOUTME: Exercise reaper safety using disposable real Git repositories and live Multica reads.
# ABOUTME: Cover retained work, ownership validation, remote evidence, pruning, and recovery.
import json
import os
import shutil
import uuid
from pathlib import Path

import pytest
import reaper


@pytest.fixture(scope="session")
def owners():
    """Read existing issues; tests never create or change platform data."""
    wid = os.environ["REAPER_TEST_WORKSPACE"]
    result = {}
    for status in ("done", "in_progress", "cancelled"):
        issues = reaper.cli(
            "--workspace-id", wid, "issue", "list", "--status", status, "--limit", "1"
        )["issues"]
        assert issues, f"Need one existing {status} issue in REAPER_TEST_WORKSPACE"
        result[status] = (wid, str(uuid.uuid4()), issues[0]["id"])
    return result


@pytest.fixture
def repo(tmp_path):
    remote, repo = tmp_path / "remote.git", tmp_path / "repo"
    reaper.run("git", "init", "--bare", "--initial-branch=main", str(remote))
    reaper.run("git", "init", "--initial-branch=main", str(repo))
    reaper.git(repo, "config", "commit.gpgsign", "false")
    reaper.git(repo, "commit", "--allow-empty", "-m", "base")
    reaper.git(repo, "remote", "add", "origin", str(remote))
    reaper.git(repo, "push", "-u", "origin", "main")
    return repo


def create_branch(repo, owner, state="merged", name="agent/test/unrelated-name"):
    base = reaper.git(repo, "rev-parse", "main")
    tree = reaper.git(repo, "rev-parse", "main^{tree}")
    tip = (
        base
        if state == "merged"
        else reaper.git(
            repo, "commit-tree", tree, "-p", base, "-m", "valuable local work"
        )
    )
    reaper.git(repo, "branch", name, tip)
    snapshot = reaper.git(repo, "commit-tree", tree, "-p", base, "-m", "user snapshot")
    message = "multica: task branch record\n\n" + "\n".join(
        f"{key}: {value}"
        for key, value in zip(
            ("Multica-Workspace", "Multica-Agent", "Multica-Conversation"), owner
        )
    )
    record = reaper.git(
        repo, "commit-tree", tree, "-p", snapshot, "-p", tip, "-m", message
    )
    reaper.git(repo, "update-ref", reaper.STATE_REF + name, record)
    if state == "pushed":
        reaper.git(repo, "push", "-u", "origin", name)
    return name, tip, record


def exists(repo, branch):
    return bool(
        reaper.git(repo, "for-each-ref", "--format=%(refname)", "refs/heads/" + branch)
    )


def audit(worker):
    return [
        json.loads(line)
        for line in (worker.state / "audit.jsonl").read_text().splitlines()
    ]


@pytest.mark.parametrize(
    "status,state,deleted,reason",
    [
        ("done", "merged", True, "merged"),
        ("done", "pushed", True, "pushed_equal"),
        ("done", "local", False, "done_unpushed"),
        ("in_progress", "merged", False, "not_done"),
        ("in_progress", "pushed", False, "not_done"),
        ("in_progress", "local", False, "not_done"),
        ("cancelled", "merged", False, "cancelled"),
    ],
)
def test_status_and_preservation_matrix(
    repo, owners, tmp_path, capsys, status, state, deleted, reason
):
    owner = owners[status]
    branch, tip, record = create_branch(repo, owner, state)
    worker = reaper.Reaper(tmp_path / "audit", apply=True)
    worker.repository(repo, {owner[0]})
    assert exists(repo, branch) is not deleted
    assert worker.counts[reason] == 1
    if deleted:
        assert not reaper.git(
            repo, "for-each-ref", "--format=%(refname)", reaper.STATE_REF + branch
        )
        (bundle,) = (worker.state / "backups").glob("*.bundle")
        reaper.git(
            repo,
            "fetch",
            str(bundle),
            f"refs/heads/{branch}:refs/heads/{branch}",
            f"{reaper.STATE_REF}{branch}:{reaper.STATE_REF}{branch}",
        )
        assert reaper.git(repo, "rev-parse", branch) == tip
        assert reaper.git(repo, "rev-parse", reaper.STATE_REF + branch) == record
    elif reason == "done_unpushed":
        event = next(
            row for row in audit(worker) if row["action"] == "KEEP_UNIQUE_WORK"
        )
        assert any("valuable local work" in subject for subject in event["commits"])
    assert capsys.readouterr().err == ""


@pytest.mark.parametrize(
    "damage",
    [
        "missing",
        "no_checkpoint",
        "wrong_history",
        "unknown_issue",
        "wrong_workspace",
        "symbolic",
    ],
)
def test_unresolvable_ownership_is_kept(repo, owners, tmp_path, capsys, damage):
    owner = owners["done"]
    if damage == "unknown_issue":
        owner = (*owner[:2], str(uuid.uuid4()))
    branch, tip, _ = create_branch(repo, owner, "local")
    ref = reaper.STATE_REF + branch
    if damage == "missing":
        reaper.git(repo, "update-ref", "-d", ref)
    elif damage == "no_checkpoint":
        reaper.git(repo, "update-ref", ref, tip)
    elif damage == "wrong_history":
        reaper.git(
            repo,
            "update-ref",
            "refs/heads/" + branch,
            reaper.git(repo, "rev-parse", "main"),
        )
    elif damage == "symbolic":
        reaper.git(repo, "symbolic-ref", ref, "refs/heads/main")
    worker = reaper.Reaper(tmp_path / "audit", apply=True)
    worker.repository(
        repo, {str(uuid.uuid4())} if damage == "wrong_workspace" else {owner[0]}
    )
    assert exists(repo, branch)
    assert worker.counts["unresolvable"] == 1
    assert capsys.readouterr().err == ""


def test_stale_remote_tracking_is_not_proof(repo, owners, tmp_path, capsys):
    owner = owners["done"]
    branch, tip, _ = create_branch(repo, owner, "pushed")
    remote = repo.parent / "remote.git"
    reaper.git(remote, "update-ref", "-d", "refs/heads/" + branch)
    assert reaper.git(repo, "rev-parse", "refs/remotes/origin/" + branch) == tip
    worker = reaper.Reaper(tmp_path / "audit", apply=True)
    worker.repository(repo, {owner[0]})
    assert exists(repo, branch)
    assert worker.counts["done_unpushed"] == 1
    assert capsys.readouterr().err == ""


@pytest.mark.parametrize("mode", ["missing", "existing", "locked", "dry_run", "mixed"])
def test_worktree_pruning(repo, owners, tmp_path, capsys, mode):
    owner = owners["done"]
    branch, _, _ = create_branch(repo, owner)
    checkout = tmp_path / "checkout"
    reaper.git(repo, "worktree", "add", str(checkout), branch)
    if mode == "locked":
        reaper.git(repo, "worktree", "lock", str(checkout))
    if mode != "existing":
        shutil.rmtree(checkout)
    if mode == "mixed":
        other, _, _ = create_branch(
            repo, owners["in_progress"], name="agent/test/active"
        )
        other_path = tmp_path / "other"
        reaper.git(repo, "worktree", "add", str(other_path), other)
        shutil.rmtree(other_path)
    worker = reaper.Reaper(tmp_path / "audit", apply=mode != "dry_run")
    before = reaper.git(repo, "show-ref")
    worker.repository(repo, {owner[0]})
    assert exists(repo, branch) is (mode != "missing")
    assert (len(reaper.worktrees(repo)) == 1) is (mode == "missing")
    if mode == "dry_run":
        assert before == reaper.git(repo, "show-ref")
        assert not (worker.state / "backups").exists()
    assert capsys.readouterr().err == ""


def test_failed_remote_preserves_work(repo, owners, tmp_path, capsys):
    owner = owners["done"]
    branch, _, _ = create_branch(repo, owner, "pushed")
    reaper.git(repo, "remote", "set-url", "origin", str(tmp_path / "absent.git"))
    worker = reaper.Reaper(tmp_path / "audit", apply=True)
    worker.repository(repo, {owner[0]})
    assert exists(repo, branch)
    assert worker.counts["remote_unverified"] == 1
    assert capsys.readouterr().err == ""


def test_wrong_daemon_fails_closed(tmp_path):
    result = reaper.run(
        "python3",
        str(Path(reaper.__file__)),
        "--profile",
        "desktop-garage-multica.tail90165f.ts.net",
        "--daemon-id",
        str(uuid.uuid4()),
        "--state-dir",
        str(tmp_path / "audit"),
        ok=(1,),
    )
    assert result.returncode == 1
    assert result.stderr == "multica-reaper failed; inspect audit.jsonl\n"
    assert json.loads(result.stdout.splitlines()[-1])["errors"] == 1


@pytest.mark.parametrize("changed", ["branch", "ownership"])
def test_changed_ref_aborts_both_deletions(repo, owners, changed):
    branch, tip, oid = create_branch(repo, owners["done"])
    ref = "refs/heads/" + branch if changed == "branch" else reaper.STATE_REF + branch
    replacement = reaper.git(
        repo, "commit-tree", "main^{tree}", "-p", tip, "-m", "concurrent work"
    )
    reaper.git(repo, "update-ref", ref, replacement)
    before = reaper.git(repo, "show-ref")
    with pytest.raises(reaper.Unsafe):
        reaper.delete_refs(repo, branch, tip, oid)
    assert before == reaper.git(repo, "show-ref")


def test_apply_twice_is_idempotent(repo, owners, tmp_path, capsys):
    owner = owners["done"]
    create_branch(repo, owner)
    worker = reaper.Reaper(tmp_path / "audit", apply=True)
    worker.repository(repo, {owner[0]})
    before = reaper.git(repo, "show-ref")
    worker.repository(repo, {owner[0]})
    assert before == reaper.git(repo, "show-ref")
    assert len(list((worker.state / "backups").glob("*.bundle"))) == 1
    assert capsys.readouterr().err == ""


def test_explicit_profile_reads_live_daemon_resources_and_issue(
    tmp_path, owners, capsys
):
    profile = "desktop-garage-multica.tail90165f.ts.net"
    binary = "/Applications/Multica.app/Contents/Resources/app.asar.unpacked/resources/bin/multica"
    worker = reaper.Reaper(tmp_path / "audit", profile=profile, binary=binary)
    status = worker.cli("daemon", "status")
    assert status["profile"] == profile
    assert status["status"] == "running"
    assert worker.discover(status["daemon_id"])
    assert reaper.issue_status(owners["done"], profile, binary) == "done"
    assert capsys.readouterr().err == ""


def test_stopped_profile_fails_closed(tmp_path):
    status = reaper.cli("daemon", "status", profile="desktop-localhost-8080")
    assert status["status"] != "running", (
        "This check requires the stopped localhost daemon"
    )
    worker = reaper.Reaper(
        tmp_path / "audit", apply=True, profile="desktop-localhost-8080"
    )
    with pytest.raises(reaper.Unsafe, match="configured daemon is not running"):
        worker.discover("01a0b3e7-caf5-74c2-8c1e-39788fb67724")
    assert not (worker.state / "backups").exists()
