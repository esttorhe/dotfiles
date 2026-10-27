# ABOUTME: Save and restore Rex sessions, tabs, splits, directories and known programs, like tmux-resurrect.
# ABOUTME: A periodic tick restores the last snapshot once per server start, then keeps saving new ones.
"""Standard-library-only. Python 3.9 compatible because launchd may run the system python3."""

import argparse
import fcntl
import json
import os
import shlex
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import unquote, urlparse

SHELL_FLAVOR = "com.superlogical.terminal.shell"
APP_BUNDLE_REX = (
    "/Applications/Rex Beta.app/Contents/Helpers/Rex Server.rex/Contents/MacOS/rex"
)
# Programs relaunched by name in their directory. Rex reports names, not arguments.
RESTORABLE = frozenset(
    ("nvim", "vim", "vi", "lazygit", "yazi", "htop", "btop", "top", "claude")
)
DEFAULT_KEEP = 50


class RexError(RuntimeError):
    pass


def rex_bin():
    return os.environ.get("REX_BIN") or shutil.which("rex") or APP_BUNDLE_REX


def rex(*args, json_output=True):
    """Run the rex CLI without starting a server, so a scheduled run never creates one."""
    cmd = [rex_bin(), "--autostart=false", *args]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=30, check=False)
    if proc.returncode != 0:
        raise RexError(
            f"{' '.join(args[:3])}: {proc.stderr.strip() or proc.stdout.strip()}"
        )
    if not json_output:
        return proc.stdout
    return json.loads(proc.stdout) if proc.stdout.strip() else None


def api(method, params):
    return rex("api", "call", method, json.dumps(params))


def block_call(session_id, block_id, method):
    return rex("block", "call", "-s", session_id, "-b", block_id, method)


def list_sessions():
    return rex("ls", "--json")["sessions"]


def session_id_for_label(label):
    for session in list_sessions():
        if session["label"] == label:
            return session["session_id"]
    return None


def server_instance():
    return rex("whoami", "--json")["instance_id"]


# ---------------------------------------------------------------------------
# Snapshot
# ---------------------------------------------------------------------------


def pane_node(label, cwd, program, session_name, block_id=None):
    return {
        "pane": {
            "block_id": block_id,
            "label": label,
            "cwd": cwd,
            "program": program,
            "session_name": session_name,
        }
    }


def panes(node):
    """Panes in layout order, the before side of each split ahead of its after side."""
    if "split" in node:
        return panes(node["split"]["before"]) + panes(node["split"]["after"])
    return [node["pane"]]


def claude_session_id(pid):
    """The conversation a running Claude instance has open, from the sessions/<pid>.json file
    Claude Code keeps for each process; None when the file is missing or unreadable."""
    if pid is None:
        return None
    config = os.environ.get("CLAUDE_CONFIG_DIR") or "~/.claude"
    path = Path(config).expanduser() / "sessions" / f"{pid}.json"
    try:
        return json.loads(path.read_text()).get("sessionId") or None
    except (OSError, ValueError, AttributeError):
        return None


def program_for(process, title):
    """The restorable program in the foreground, and the Claude session to resume: its exact
    id when the running instance reports one, else the session name its title shows."""
    foreground = (process or {}).get("foreground") or {}
    name = foreground.get("name")
    if name not in RESTORABLE:
        return None
    session_name = None
    if name == "claude":
        session_name = claude_session_id(foreground.get("pid"))
        text = ((title or {}).get("title") or "").strip()
        if not session_name and text.startswith("✳"):
            session_name = text.lstrip("✳").strip() or None
    return name, session_name


def cwd_for(pwd, process):
    """Prefer the directory the shell reported; fall back to any process that knows its own."""
    url = (pwd or {}).get("pwd") or ""
    if url:
        path = unquote(urlparse(url).path) if url.startswith("file://") else url
        if path:
            return path
    for proc in (process or {}).get("ancestors") or []:
        if proc.get("cwd"):
            return proc["cwd"]
    return ""


def snapshot_pane(session_id, block):
    block_id = block["block_id"]
    process = block_call(session_id, block_id, "process")
    pwd = block_call(session_id, block_id, "pwd")
    title = block_call(session_id, block_id, "title")
    found = program_for(process, title)
    program, session_name = found if found else (None, None)
    label = block.get("label") or ""
    node = pane_node(
        "" if label == "shell" else label,
        cwd_for(pwd, process),
        program,
        session_name,
        block_id,
    )
    # Without an id or name, --continue would put every such pane in a directory into the
    # same most recent conversation, so these open Claude's resume picker instead.
    if program == "claude" and not session_name:
        node["pane"]["picker"] = True
    return node


def snapshot_layout(session_id, layout, blocks):
    if "split" in layout:
        s = layout["split"]
        return {
            "split": {
                "direction": s["direction"],
                "ratio": s["ratio"],
                "before": snapshot_layout(session_id, s["before"], blocks),
                "after": snapshot_layout(session_id, s["after"], blocks),
            }
        }
    return snapshot_pane(session_id, blocks[layout["block_id"]])


def snapshot_session(session_id):
    view = api("session.view", {"session_id": session_id})
    windows = []
    for window in view["windows"]:
        # Floating layers are left out: only the tiled layout is rebuilt.
        tiled = [layer for layer in window["layers"] if layer.get("kind") == "tiled"]
        if not tiled:
            continue
        blocks = {b["block_id"]: b for b in tiled[0]["blocks"]}
        windows.append(
            {
                "label": window.get("label") or "",
                "active": window["window_id"] == view.get("active_window_id"),
                "layout": snapshot_layout(session_id, tiled[0]["layout"], blocks),
            }
        )
    return {"label": view["label"], "windows": windows}


def is_idle_home_shell(session):
    """A session holding nothing but one idle shell in the home directory, like the one
    the app opens on start. Saving those would bring back one more after every restart."""
    if len(session["windows"]) != 1:
        return False
    found = panes(session["windows"][0]["layout"])
    return (
        len(found) == 1
        and not found[0]["program"]
        and found[0]["cwd"].rstrip("/") == str(Path.home())
    )


def snapshot_all():
    sessions = [snapshot_session(s["session_id"]) for s in list_sessions()]
    return {
        "version": 1,
        "saved_at": datetime.now(timezone.utc).isoformat(),
        "sessions": [s for s in sessions if not is_idle_home_shell(s)],
    }


# ---------------------------------------------------------------------------
# Restore
# ---------------------------------------------------------------------------


def launch_command(program, session_name, picker=False):
    """picker opens Claude's resume picker for an unnamed session, where --continue
    would guess when several panes share a directory."""
    if program == "claude":
        if session_name:
            return f"claude --resume {shlex.quote(session_name)}"
        return "claude --resume" if picker else "claude --continue"
    return program


def create_layout(node):
    if "split" in node:
        s = node["split"]
        return {
            "split": {
                "direction": s["direction"],
                "ratio": s["ratio"],
                "before": create_layout(s["before"]),
                "after": create_layout(s["after"]),
            }
        }
    pane = node["pane"]
    block = {"flavor": SHELL_FLAVOR, "options": {"cwd": pane["cwd"]}}
    if pane.get("label"):
        block["label"] = pane["label"]
    return {"block": block}


def restore(snapshot, start=True):
    """Recreate every saved session whose label isn't open already. With start=False each
    program's command is typed at the prompt but not run, for the user to start later."""
    existing = {s["label"] for s in list_sessions()}
    result = {"restored": [], "skipped": []}
    for session in snapshot.get("sessions", []):
        if session["label"] in existing or not session["windows"]:
            result["skipped"].append(session["label"])
            continue
        created = api(
            "session.create",
            {
                "label": session["label"],
                "initial_windows": [
                    {"window_label": w["label"], "layout": create_layout(w["layout"])}
                    for w in session["windows"]
                ],
            },
        )
        session_id = created["session_id"]
        for window, made in zip(session["windows"], created["initial_windows"]):
            # Programs are typed into the shell, like tmux-resurrect, so quitting returns to a prompt.
            for pane, block_id in zip(panes(window["layout"]), made["block_ids"]):
                if pane.get("program"):
                    command = launch_command(
                        pane["program"],
                        pane.get("session_name"),
                        picker=pane.get("picker", False),
                    )
                    rex(
                        "send",
                        "-s",
                        session_id,
                        "-b",
                        block_id,
                        command,
                        json_output=False,
                    )
                    if not start:
                        continue
                    rex(
                        "send-key",
                        "-s",
                        session_id,
                        "-b",
                        block_id,
                        "enter",
                        json_output=False,
                    )
            if window.get("active"):
                api(
                    "session.focus_window",
                    {"session_id": session_id, "window_id": made["window_id"]},
                )
        result["restored"].append(session["label"])
    return result


# ---------------------------------------------------------------------------
# Importing from tmux
# ---------------------------------------------------------------------------


def _nest_tmux(direction, children, total):
    """Nest any number of (node, width, height) children two at a time. Each ratio
    counts the pane's border, so the sizes add up to the parent's."""
    if len(children) == 1:
        return children[0][0]
    first, rest = children[0], children[1:]
    first_size = first[1] if direction == "horizontal" else first[2]
    return (
        "split",
        direction,
        min((first_size + 1) / total, 0.99),
        first[0],
        _nest_tmux(direction, rest, total - first_size - 1),
    )


def _parse_tmux_json(node):
    """Newer tmux reports layouts as JSON: t is p (pane), h (side by side) or v (stacked)."""
    width, height = node["w"], node["h"]
    if node["t"] == "p":
        return ("pane", int(node["I"].lstrip("%"))), width, height
    direction = "horizontal" if node["t"] == "h" else "vertical"
    children = [_parse_tmux_json(child) for child in node["c"]]
    size = width if direction == "horizontal" else height
    return _nest_tmux(direction, children, size), width, height


def parse_tmux_layout(layout):
    """Parse a tmux window_layout into ("pane", id) and
    ("split", direction, ratio, before, after) tuples. Older tmux servers report the
    classic "csum,WxH,X,Y{...}" string, newer ones a JSON object."""
    if layout.lstrip().startswith("{"):
        return _parse_tmux_json(json.loads(layout)["L"])[0]

    text = layout.split(",", 1)[1]  # drop the checksum
    pos = 0

    def number():
        nonlocal pos
        start = pos
        while pos < len(text) and text[pos].isdigit():
            pos += 1
        return int(text[start:pos])

    def cell():
        nonlocal pos
        width = number()
        pos += 1  # x
        height = number()
        pos += 1  # ,
        number()  # left offset
        pos += 1  # ,
        number()  # top offset
        if pos < len(text) and text[pos] in "{[":
            direction = "horizontal" if text[pos] == "{" else "vertical"
            pos += 1
            children = [cell()]
            while text[pos] == ",":
                pos += 1
                children.append(cell())
            pos += 1  # closing bracket
            size = width if direction == "horizontal" else height
            return _nest_tmux(direction, children, size), width, height
        pos += 1  # ,
        return ("pane", number()), width, height

    return cell()[0]


def tmux_program(command, title):
    """The restorable program a tmux pane runs, and Claude's session name from its title."""
    if command == "claude":
        text = (title or "").strip()
        return "claude", (text.lstrip("✳").strip() or None) if text.startswith(
            "✳"
        ) else None
    return (command, None) if command in RESTORABLE else (None, None)


def tmux_lines(tmux_bin, socket, *args):
    cmd = [tmux_bin] + (["-L", socket] if socket else []) + list(args)
    out = subprocess.run(
        cmd, capture_output=True, text=True, timeout=30, check=True
    ).stdout
    return [line.split("\t") for line in out.splitlines() if line]


def import_tmux(tmux_bin="tmux", socket=None):
    """Read every tmux session into a snapshot that restore() can rebuild in Rex."""
    panes_by_id = {}
    for pane_id, command, title, path in tmux_lines(
        tmux_bin,
        socket,
        "list-panes",
        "-a",
        "-F",
        "#{pane_id}\t#{pane_current_command}\t#{pane_title}\t#{pane_current_path}",
    ):
        program, session_name = tmux_program(command, title)
        node = pane_node("", path, program, session_name)
        if program == "claude" and not session_name:
            node["pane"]["picker"] = True
        panes_by_id[int(pane_id.lstrip("%"))] = node

    def convert(tree):
        if tree[0] == "pane":
            return panes_by_id[tree[1]]
        _, direction, ratio, before, after = tree
        return {
            "split": {
                "direction": direction,
                "ratio": ratio,
                "before": convert(before),
                "after": convert(after),
            }
        }

    sessions = {}
    for session, name, active, layout in tmux_lines(
        tmux_bin,
        socket,
        "list-windows",
        "-a",
        "-F",
        "#{session_name}\t#{window_name}\t#{window_active}\t#{window_layout}",
    ):
        sessions.setdefault(session, []).append(
            {
                "label": name,
                "active": active == "1",
                "layout": convert(parse_tmux_layout(layout)),
            }
        )
    return {
        "version": 1,
        "saved_at": datetime.now(timezone.utc).isoformat(),
        "source": "tmux",
        "sessions": [{"label": s, "windows": w} for s, w in sessions.items()],
    }


# ---------------------------------------------------------------------------
# State, saving and the scheduled tick
# ---------------------------------------------------------------------------


def state_dir():
    path = os.environ.get("REX_RESURRECT_STATE") or "~/.local/state/rex-resurrect"
    d = Path(path).expanduser()
    (d / "snapshots").mkdir(parents=True, exist_ok=True)
    return d


def read_json(path, default):
    try:
        return json.loads(Path(path).read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return default


def write_json(path, data):
    tmp = Path(f"{path}.tmp")
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False))
    os.replace(tmp, path)


def settled_instance():
    return read_json(state_dir() / "state.json", {}).get("settled_instance")


def mark_settled(instance):
    write_json(state_dir() / "state.json", {"settled_instance": instance})


def save(force=False, keep=DEFAULT_KEEP):
    """Write a snapshot. Unforced saves wait until this server's restore has happened,
    so a freshly started, empty server never overwrites the snapshot it should restore."""
    instance = server_instance()
    if not force and settled_instance() != instance:
        return {"saved": False, "reason": "server not restored yet"}
    if force:
        mark_settled(instance)
    d = state_dir()
    snap = snapshot_all()
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    path = d / "snapshots" / f"{stamp}.json"
    write_json(path, snap)
    write_json(d / "last.json", snap)
    for old in sorted((d / "snapshots").glob("*.json"))[:-keep]:
        old.unlink()
    return {"saved": True, "path": str(path), "sessions": len(snap["sessions"])}


def restore_last():
    instance = server_instance()
    result = restore(read_json(state_dir() / "last.json", {"sessions": []}))
    mark_settled(instance)
    return result


def tick():
    """Restore once for each new server, then save. Run every few minutes by launchd."""
    restored = []
    if settled_instance() != server_instance():
        restored = restore_last()["restored"]
    saved = save(force=False)
    return {"restored": restored, "saved": saved["saved"]}


def locked(fn, *args, **kwargs):
    with open(state_dir() / "lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        return fn(*args, **kwargs)


def main(argv=None):
    parser = argparse.ArgumentParser(prog="rex-resurrect", description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("save", help="snapshot every session now")
    restore_cmd = sub.add_parser("restore", help="recreate sessions from a snapshot")
    restore_cmd.add_argument(
        "--snapshot", help="a file under snapshots/ instead of the last one"
    )
    restore_cmd.add_argument(
        "--no-start",
        action="store_true",
        help="type each program's command at its prompt without running it",
    )
    sub.add_parser(
        "tick", help="restore once per server start, then save (for launchd)"
    )
    sub.add_parser("list", help="list saved snapshots, newest last")
    import_cmd = sub.add_parser(
        "import-tmux", help="write tmux's sessions as a snapshot for restore"
    )
    import_cmd.add_argument("--tmux", default=shutil.which("tmux") or "tmux")
    import_cmd.add_argument("--socket", help="a tmux -L socket name")
    import_cmd.add_argument("--output", required=True, help="where to write it")
    args = parser.parse_args(argv)

    try:
        if args.command == "save":
            result = locked(save, force=True)
        elif args.command == "restore":
            start = not args.no_start
            if args.snapshot:
                snap = read_json(args.snapshot, {"sessions": []})
                result = locked(restore, snap, start=start)
            elif start:
                result = locked(restore_last)
            else:
                snap = read_json(state_dir() / "last.json", {"sessions": []})
                result = locked(restore, snap, start=False)
        elif args.command == "import-tmux":
            snap = import_tmux(args.tmux, socket=args.socket)
            write_json(Path(args.output).expanduser(), snap)
            result = {
                "path": args.output,
                "sessions": [s["label"] for s in snap["sessions"]],
            }
        elif args.command == "tick":
            result = locked(tick)
        else:
            result = [
                p.name for p in sorted((state_dir() / "snapshots").glob("*.json"))
            ]
    except RexError as err:
        # No server running (the app is closed) is normal for a scheduled run.
        print(json.dumps({"error": str(err)}), file=sys.stderr)
        return 1
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
