# ABOUTME: Run a command in a visible floating Rex pane over the caller's tab, or in a split with --split.
# ABOUTME: Lets agents show long-running commands (servers, tests, logs) where the user can watch them.
"""Standard-library-only. Python 3.9 compatible.

Usage: rex-run [--label NAME] [--cwd DIR] [--focus] [--close-on-exit]
               [--minimized | --split] -- COMMAND...
       rex-run --minimize BLOCK
       rex-run --restore BLOCK

The pane running rex-run's caller is $REX_BLOCK in $REX_SESSION. By default the
command opens in a floating pane over the right of the caller's tab, each new one
offset from the last, and the caller keeps focus. --minimized starts it
minimized. --minimize and --restore change the floating pane holding BLOCK.
With --split the command opens in a pane beside the caller instead: right of a
lone pane, else stacked below the last command pane. Prints JSON with the new
block_id (and layer_id for floating panes) for `rex capture` and `rex wait`."""

import argparse
import json
import os
import shutil
import subprocess
import sys

SHELL_FLAVOR = "com.superlogical.terminal.shell"
# Where the first floating pane sits, as fractions of the window: x, y, width, height.
FLOAT_BOUNDS = [0.45, 0.06, 0.52, 0.82]
# Each further floating pane moves this much left and down, wrapping after CASCADE_STEPS.
CASCADE = 0.03
CASCADE_STEPS = 4

APP_BUNDLE_REX = (
    "/Applications/Rex Beta.app/Contents/Helpers/Rex Server.rex/Contents/MacOS/rex"
)


def rex(*args):
    binary = os.environ.get("REX_BIN") or shutil.which("rex") or APP_BUNDLE_REX
    proc = subprocess.run(
        [binary, "--autostart=false", *args],
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip())
    return json.loads(proc.stdout) if proc.stdout.strip() else None


def blocks_in_order(node):
    """Blocks left to right and top to bottom: each split's before side first."""
    if "split" in node:
        return blocks_in_order(node["split"]["before"]) + blocks_in_order(
            node["split"]["after"]
        )
    return [node["block_id"]]


def choose_placement(layout, caller):
    """(block to split, direction) for a new command pane in the caller's tab."""
    blocks = blocks_in_order(layout)
    others = [b for b in blocks if b != caller]
    if not others:
        return caller, "right"
    return others[-1], "below"


def floating_bounds(count):
    """Bounds for a floating pane when the tab already has `count` of them."""
    step = count % CASCADE_STEPS
    x, y, w, h = FLOAT_BOUNDS
    return [round(x - CASCADE * step, 4), round(y + CASCADE * step, 4), w, h]


def session_view(session_id):
    return rex("api", "call", "session.view", json.dumps({"session_id": session_id}))


def caller_window(session_id, caller):
    for window in session_windows(session_id):
        for layer in window["layers"]:
            if any(b["block_id"] == caller for b in layer.get("blocks", [])):
                return window
    raise RuntimeError(f"pane {caller} isn't in a tab of session {session_id}")


def session_windows(session_id):
    return session_view(session_id)["windows"]


def caller_layout(session_id, caller):
    for window in session_windows(session_id):
        for layer in window["layers"]:
            if layer.get("kind") != "tiled":
                continue
            if caller in blocks_in_order(layer["layout"]):
                return layer["layout"]
    raise RuntimeError(f"pane {caller} isn't in a tab of session {session_id}")


def run(
    session_id,
    caller,
    command,
    label=None,
    cwd=None,
    focus=False,
    keep_open=True,
    minimized=False,
    split=False,
):
    if split:
        return run_split(session_id, caller, command, label, cwd, focus, keep_open)
    return run_floating(
        session_id, caller, command, label, cwd, focus, keep_open, minimized
    )


def run_floating(session_id, caller, command, label, cwd, focus, keep_open, minimized):
    window = caller_window(session_id, caller)
    floating = [l for l in window["layers"] if l.get("kind") == "floating"]
    options = {"command": list(command), "cwd": cwd or os.getcwd()}
    if keep_open:
        options["exit"] = {"on_completion": False}
    block = {"flavor": SHELL_FLAVOR, "options": options}
    if label:
        block["label"] = label
    created = rex(
        "api",
        "call",
        "session.new_layer",
        json.dumps(
            {
                "session_id": session_id,
                "window_id": window["window_id"],
                "bounds": floating_bounds(len(floating)),
                "focus": bool(focus) and not minimized,
                "layout": {"block": block},
            }
        ),
    )
    if minimized:
        change_layer(session_id, created["layer_id"], "minimized")
    return {"block_id": created["block_ids"][0], "layer_id": created["layer_id"]}


def change_layer(session_id, layer_id, state):
    rex(
        "api",
        "call",
        "session.set_layer_state",
        json.dumps({"session_id": session_id, "layer_id": layer_id, "state": state}),
    )


def set_state(session_id, block_id, state):
    """Minimize ('minimized') or restore ('normal') the floating pane holding block_id."""
    for window in session_windows(session_id):
        for layer in window["layers"]:
            if any(b["block_id"] == block_id for b in layer.get("blocks", [])):
                if layer.get("kind") != "floating":
                    raise RuntimeError(f"pane {block_id} isn't in a floating pane")
                change_layer(session_id, layer["layer_id"], state)
                return {"block_id": block_id, "layer_id": layer["layer_id"], "state": state}
    raise RuntimeError(f"pane {block_id} isn't in session {session_id}")


def run_split(session_id, caller, command, label, cwd, focus, keep_open):
    target, direction = choose_placement(caller_layout(session_id, caller), caller)
    args = ["split", "-s", session_id, "-b", target, f"--split={direction}"]
    if direction == "right":
        args.append("--ratio=40")
    args.append(f"--focus={'true' if focus else 'false'}")
    if keep_open:
        args.append("--keep-open")
    if label:
        args += ["--label", label]
    args += ["-c", cwd or os.getcwd(), "--json", "--", *command]
    created = rex(*args)
    return {
        "block_id": created["block_ids"][0],
        "target": target,
        "direction": direction,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="rex-run",
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--label", help="name shown on the pane")
    parser.add_argument("--cwd", help="directory to run in (default: the current one)")
    parser.add_argument(
        "--focus", action="store_true", help="move focus to the new pane"
    )
    parser.add_argument(
        "--close-on-exit",
        action="store_true",
        help="close the pane when the command exits instead of keeping its output",
    )
    placement = parser.add_mutually_exclusive_group()
    placement.add_argument(
        "--minimized", action="store_true", help="start the floating pane minimized"
    )
    placement.add_argument(
        "--split",
        action="store_true",
        help="open a pane beside the caller instead of a floating pane",
    )
    placement.add_argument(
        "--minimize", metavar="BLOCK", help="minimize the floating pane holding BLOCK"
    )
    placement.add_argument(
        "--restore", metavar="BLOCK", help="restore the floating pane holding BLOCK"
    )
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    session_id = os.environ.get("REX_SESSION")
    caller = os.environ.get("REX_BLOCK")
    changing = args.minimize or args.restore
    if changing and command:
        parser.error("--minimize and --restore don't take a command")
    if not changing and not command:
        parser.error("give a command after --")
    if not session_id or not caller:
        print(
            "rex-run: not inside a Rex pane (REX_SESSION/REX_BLOCK unset)",
            file=sys.stderr,
        )
        return 2
    try:
        if changing:
            state = "minimized" if args.minimize else "normal"
            result = set_state(session_id, changing, state)
        else:
            result = run(
                session_id,
                caller,
                command,
                label=args.label,
                cwd=args.cwd,
                focus=args.focus,
                keep_open=not args.close_on_exit,
                minimized=args.minimized,
                split=args.split,
            )
    except RuntimeError as err:
        print(f"rex-run: {err}", file=sys.stderr)
        return 1
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
