# ABOUTME: Exercise rex-resurrect against the live local Rex server with disposable rrtest- sessions.
# ABOUTME: Cover layout round trips, program restore, duplicate protection, and the save/restore guard.
import json
import time
import uuid

import pytest
import rex_resurrect as rr

SHELL = "com.superlogical.terminal.shell"


@pytest.fixture
def state_dir(tmp_path, monkeypatch):
    """Keep snapshots and state away from the real ~/.local/state/rex-resurrect."""
    monkeypatch.setenv("REX_RESURRECT_STATE", str(tmp_path))
    return tmp_path


@pytest.fixture
def label():
    """A unique session label; any session left with it is destroyed afterwards."""
    name = f"rrtest-{uuid.uuid4().hex[:8]}"
    yield name
    for session in rr.list_sessions():
        if session["label"].startswith(name):
            rr.rex("kill", session["session_id"], json_output=False)


def make_split_session(name, tmp_path):
    """Two tabs: the first split right 70/30, its right side split again top/bottom."""
    left, top, bottom, other = (
        tmp_path / d for d in ("left", "top", "bottom", "other")
    )
    for d in (left, top, bottom, other):
        d.mkdir()
    created = rr.api(
        "session.create",
        {
            "label": name,
            "initial_windows": [
                {
                    "window_label": "editor",
                    "layout": {
                        "split": {
                            "direction": "horizontal",
                            "ratio": 0.7,
                            "before": {
                                "block": {
                                    "flavor": SHELL,
                                    "options": {"cwd": str(left)},
                                }
                            },
                            "after": {
                                "split": {
                                    "direction": "vertical",
                                    "ratio": 0.5,
                                    "before": {
                                        "block": {
                                            "flavor": SHELL,
                                            "options": {"cwd": str(top)},
                                        }
                                    },
                                    "after": {
                                        "block": {
                                            "flavor": SHELL,
                                            "options": {"cwd": str(bottom)},
                                        }
                                    },
                                }
                            },
                        }
                    },
                },
                {
                    "window_label": "logs",
                    "layout": {
                        "block": {"flavor": SHELL, "options": {"cwd": str(other)}}
                    },
                },
            ],
        },
    )
    wait_for_shells(created["session_id"])
    return created["session_id"], [str(d) for d in (left, top, bottom, other)]


def wait_for_shells(session_id, timeout=15):
    """Shells report their directory once they reach a prompt."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        panes = [
            p
            for w in rr.snapshot_session(session_id)["windows"]
            for p in rr.panes(w["layout"])
        ]
        if all(p["cwd"] for p in panes):
            return
        time.sleep(0.5)
    raise AssertionError("shells never reported a working directory")


def shape(node):
    """The layout without volatile details: directions, rounded ratios, and directories."""
    if "split" in node:
        s = node["split"]
        return [
            s["direction"],
            round(s["ratio"], 2),
            shape(s["before"]),
            shape(s["after"]),
        ]
    return node["pane"]["cwd"]


def test_snapshot_captures_tabs_splits_and_directories(label, tmp_path):
    session_id, dirs = make_split_session(label, tmp_path)
    snap = rr.snapshot_session(session_id)
    assert snap["label"] == label
    assert [w["label"] for w in snap["windows"]] == ["editor", "logs"]
    assert shape(snap["windows"][0]["layout"]) == [
        "horizontal",
        0.7,
        dirs[0],
        ["vertical", 0.5, dirs[1], dirs[2]],
    ]
    assert shape(snap["windows"][1]["layout"]) == dirs[3]


def test_restore_rebuilds_the_same_layout(label, tmp_path):
    session_id, _ = make_split_session(label, tmp_path)
    before = rr.snapshot_session(session_id)
    rr.rex("kill", session_id, json_output=False)

    result = rr.restore({"version": 1, "sessions": [before]})
    assert result["restored"] == [label]
    restored_id = rr.session_id_for_label(label)
    wait_for_shells(restored_id)
    after = rr.snapshot_session(restored_id)
    assert [w["label"] for w in after["windows"]] == ["editor", "logs"]
    assert [shape(w["layout"]) for w in after["windows"]] == [
        shape(w["layout"]) for w in before["windows"]
    ]


def test_restore_skips_sessions_that_already_exist(label, tmp_path):
    session_id, _ = make_split_session(label, tmp_path)
    snap = rr.snapshot_session(session_id)
    result = rr.restore({"version": 1, "sessions": [snap]})
    assert result["skipped"] == [label]
    assert [s["label"] for s in rr.list_sessions()].count(label) == 1


def test_restore_relaunches_a_known_program_in_its_directory(label, tmp_path):
    work = tmp_path / "work"
    work.mkdir()
    snap = {
        "label": label,
        "windows": [
            {
                "label": "monitor",
                "active": True,
                "layout": rr.pane_node("", str(work), "top", None),
            }
        ],
    }
    rr.restore({"version": 1, "sessions": [snap]})
    restored_id = rr.session_id_for_label(label)
    block_id = rr.panes(rr.snapshot_session(restored_id)["windows"][0]["layout"])[0][
        "block_id"
    ]
    deadline = time.time() + 15
    while time.time() < deadline:
        process = rr.block_call(restored_id, block_id, "process")
        if (process.get("foreground") or {}).get("name") == "top":
            break
        time.sleep(0.5)
    assert process["foreground"]["name"] == "top"
    assert process["ancestors"][0]["cwd"] == str(work)


def test_program_detection_uses_the_live_process_and_title():
    shell_proc = {
        "foreground": {"name": "fish"},
        "ancestors": [{"name": "fish", "cwd": "/tmp"}],
    }
    top_proc = {
        "foreground": {"name": "top"},
        "ancestors": [{"name": "fish", "cwd": "/srv"}],
    }
    claude_proc = {
        "foreground": {"name": "claude"},
        "ancestors": [{"name": "fish", "cwd": "/w"}],
    }
    assert rr.program_for(shell_proc, {"title": "~/x"}) is None
    assert rr.program_for(top_proc, {"title": "top"}) == ("top", None)
    assert rr.program_for(claude_proc, {"title": "✳ fix-login-redirect"}) == (
        "claude",
        "fix-login-redirect",
    )
    assert rr.program_for(claude_proc, {"title": "claude"}) == ("claude", None)


def test_launch_command_resumes_named_claude_sessions():
    assert rr.launch_command("nvim", None) == "nvim"
    assert (
        rr.launch_command("claude", "it's done") == "claude --resume 'it'\"'\"'s done'"
    )
    assert rr.launch_command("claude", None) == "claude --continue"


def test_save_writes_a_snapshot_and_keeps_only_the_newest(state_dir, label, tmp_path):
    make_split_session(label, tmp_path)
    for _ in range(3):
        rr.save(force=True, keep=2)
        time.sleep(1.1)
    snapshots = sorted((state_dir / "snapshots").glob("*.json"))
    assert len(snapshots) == 2
    latest = json.loads((state_dir / "last.json").read_text())
    assert label in [s["label"] for s in latest["sessions"]]


def test_tick_restores_once_per_server_and_then_saves(state_dir, label, tmp_path):
    session_id, _ = make_split_session(label, tmp_path)
    snap = rr.snapshot_session(session_id)
    rr.rex("kill", session_id, json_output=False)
    (state_dir / "last.json").write_text(json.dumps({"version": 1, "sessions": [snap]}))

    first = rr.tick()
    assert first["restored"] == [label]
    second = rr.tick()
    assert second["restored"] == []
    assert second["saved"] is True
    assert [s["label"] for s in rr.list_sessions()].count(label) == 1


def test_snapshot_leaves_out_a_lone_idle_shell_in_home(label):
    created = rr.api(
        "session.create",
        {
            "label": label,
            "initial_windows": [
                {
                    "layout": {
                        "block": {
                            "flavor": SHELL,
                            "options": {"cwd": str(rr.Path.home())},
                        }
                    }
                }
            ],
        },
    )
    wait_for_shells(created["session_id"])
    assert label not in [s["label"] for s in rr.snapshot_all()["sessions"]]


def test_unforced_save_refuses_before_this_server_has_been_restored(
    state_dir, label, tmp_path
):
    make_split_session(label, tmp_path)
    (state_dir / "last.json").write_text(json.dumps({"version": 1, "sessions": []}))
    assert rr.save(force=False)["saved"] is False
    assert json.loads((state_dir / "last.json").read_text())["sessions"] == []
