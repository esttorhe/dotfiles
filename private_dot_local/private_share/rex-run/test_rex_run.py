# ABOUTME: Exercise rex-run's pane placement against the live local Rex server with disposable sessions.
# ABOUTME: Commands open in visible floating panes by default, can be minimized and restored, or split with --split.
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


def window(session_id):
    view = rex("api", "call", "session.view", json.dumps({"session_id": session_id}))
    return view["windows"][0]


def layout(session_id):
    return window(session_id)["layers"][0]["layout"]


def layer_of(session_id, block_id):
    for layer in window(session_id)["layers"]:
        if any(b["block_id"] == block_id for b in layer["blocks"]):
            return layer
    return None


def state(layer):
    """Rex reports state only for minimized layers; a normal one leaves it out."""
    return layer.get("state", "normal")


def shape(node):
    if "split" in node:
        s = node["split"]
        return [s["direction"], shape(s["before"]), shape(s["after"])]
    return node["block_id"]


def test_a_command_opens_in_a_visible_floating_pane_over_the_callers_tab(session):
    session_id, agent = session
    placed = rex_run.run(session_id, agent, ["sleep", "30"], label="server")
    layer = layer_of(session_id, placed["block_id"])
    assert layer["kind"] == "floating"
    assert state(layer) == "normal"
    assert layer["layer_id"] == placed["layer_id"]
    assert layer["blocks"][0]["label"] == "server"
    assert window(session_id)["focused_block_id"] == agent
    assert shape(layout(session_id)) == agent


def test_each_floating_pane_is_offset_from_the_last(session):
    session_id, agent = session
    first = rex_run.run(session_id, agent, ["sleep", "30"], label="first")
    second = rex_run.run(session_id, agent, ["sleep", "30"], label="second")
    a = layer_of(session_id, first["block_id"])["bounds"]
    b = layer_of(session_id, second["block_id"])["bounds"]
    assert a != b
    assert b[0] < a[0] and b[1] > a[1]


def test_the_command_runs_and_its_pane_stays_open_after_it_exits(session, tmp_path):
    session_id, agent = session
    marker = tmp_path / "ran"
    placed = rex_run.run(
        session_id, agent, ["sh", "-c", f"echo done > {marker}"], label="marker"
    )
    deadline = time.time() + 15
    while time.time() < deadline and not marker.exists():
        time.sleep(0.3)
    assert marker.read_text().strip() == "done"
    time.sleep(1)
    assert layer_of(session_id, placed["block_id"]) is not None


def test_minimized_starts_the_floating_pane_minimized(session):
    session_id, agent = session
    placed = rex_run.run(session_id, agent, ["sleep", "30"], minimized=True)
    assert state(layer_of(session_id, placed["block_id"])) == "minimized"
    assert window(session_id)["focused_block_id"] == agent


def test_a_floating_pane_can_be_minimized_and_restored_by_its_block(session):
    session_id, agent = session
    placed = rex_run.run(session_id, agent, ["sleep", "30"])
    rex_run.set_state(session_id, placed["block_id"], "minimized")
    assert state(layer_of(session_id, placed["block_id"])) == "minimized"
    rex_run.set_state(session_id, placed["block_id"], "normal")
    assert state(layer_of(session_id, placed["block_id"])) == "normal"


def test_minimizing_a_tiled_pane_is_refused(session):
    session_id, agent = session
    with pytest.raises(RuntimeError, match="isn't in a floating pane"):
        rex_run.set_state(session_id, agent, "minimized")


def test_split_puts_a_lone_panes_command_on_its_right(session):
    session_id, agent = session
    placed = rex_run.run(session_id, agent, ["sleep", "30"], label="first", split=True)
    assert placed["direction"] == "right"
    assert shape(layout(session_id)) == ["horizontal", agent, placed["block_id"]]


def test_split_stacks_new_commands_below_the_last_command_pane(session):
    session_id, agent = session
    first = rex_run.run(session_id, agent, ["sleep", "30"], label="first", split=True)
    second = rex_run.run(session_id, agent, ["sleep", "30"], label="second", split=True)
    assert second["direction"] == "below"
    assert second["target"] == first["block_id"]
    assert shape(layout(session_id)) == [
        "horizontal",
        agent,
        ["vertical", first["block_id"], second["block_id"]],
    ]
    assert window(session_id)["focused_block_id"] == agent


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


def test_floating_bounds_cascade_and_wrap_around():
    assert rex_run.floating_bounds(0) == rex_run.FLOAT_BOUNDS
    x0, y0, w, h = rex_run.floating_bounds(0)
    x1, y1, w1, h1 = rex_run.floating_bounds(1)
    assert (x1, y1) == (pytest.approx(x0 - rex_run.CASCADE), pytest.approx(y0 + rex_run.CASCADE))
    assert (w1, h1) == (w, h)
    assert rex_run.floating_bounds(rex_run.CASCADE_STEPS) == rex_run.FLOAT_BOUNDS
    for n in range(rex_run.CASCADE_STEPS):
        x, y, w, h = rex_run.floating_bounds(n)
        assert x >= 0 and y >= 0 and x + w <= 1 and y + h <= 1
