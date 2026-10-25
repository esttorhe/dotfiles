# ABOUTME: Exercise rex-run's pane placement against the live local Rex server with disposable sessions.
# ABOUTME: One pane splits to the right; once split, new panes stack below the last command pane.
import json
import subprocess
import time
import uuid

import pytest
import rex_run


def rex(*args):
    out = subprocess.run(
        ["rex", *args], capture_output=True, text=True, check=True
    ).stdout
    return json.loads(out) if out.strip().startswith("{") else out


@pytest.fixture
def session(tmp_path):
    """A one-pane session standing in for the pane an agent runs in."""
    created = rex(
        "new", f"rrtest-{uuid.uuid4().hex[:8]}", "-c", str(tmp_path), "--json"
    )
    session_id = created["session_id"]
    yield session_id, created["initial_windows"][0]["block_ids"][0]
    subprocess.run(["rex", "kill", session_id], capture_output=True, check=False)


def layout(session_id):
    view = rex("api", "call", "session.view", json.dumps({"session_id": session_id}))
    return view["windows"][0]["layers"][0]["layout"]


def shape(node):
    if "split" in node:
        s = node["split"]
        return [s["direction"], shape(s["before"]), shape(s["after"])]
    return node["block_id"]


def test_a_lone_pane_gets_the_command_on_its_right(session):
    session_id, agent = session
    placed = rex_run.run(session_id, agent, ["sleep", "30"], label="first")
    assert placed["direction"] == "right"
    assert shape(layout(session_id)) == ["horizontal", agent, placed["block_id"]]


def test_a_split_tab_stacks_new_commands_below_the_last_command_pane(session):
    session_id, agent = session
    first = rex_run.run(session_id, agent, ["sleep", "30"], label="first")
    second = rex_run.run(session_id, agent, ["sleep", "30"], label="second")
    assert second["direction"] == "below"
    assert second["target"] == first["block_id"]
    assert shape(layout(session_id)) == [
        "horizontal",
        agent,
        ["vertical", first["block_id"], second["block_id"]],
    ]


def test_the_agent_pane_keeps_focus_and_the_command_runs(session, tmp_path):
    session_id, agent = session
    marker = tmp_path / "ran"
    placed = rex_run.run(
        session_id, agent, ["sh", "-c", f"echo done > {marker}"], label="marker"
    )
    deadline = time.time() + 15
    while time.time() < deadline and not marker.exists():
        time.sleep(0.3)
    assert marker.read_text().strip() == "done"
    view = rex("api", "call", "session.view", json.dumps({"session_id": session_id}))
    assert view["windows"][0]["focused_block_id"] == agent
    assert placed["block_id"] != agent


def test_choose_placement_reads_the_layout_tree():
    one = {"block_id": "a"}
    assert rex_run.choose_placement(one, "a") == ("a", "right")
    split = {
        "split": {
            "direction": "horizontal",
            "before": {"block_id": "a"},
            "after": {
                "split": {
                    "direction": "vertical",
                    "before": {"block_id": "b"},
                    "after": {"block_id": "c"},
                }
            },
        }
    }
    assert rex_run.choose_placement(split, "a") == ("c", "below")
    # The agent pane is never chosen as the place to stack under, even when it is last.
    assert rex_run.choose_placement(split, "c") == ("b", "below")
