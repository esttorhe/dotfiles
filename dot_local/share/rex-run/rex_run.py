# ABOUTME: Run a command in a new Rex pane beside the caller: right of a lone pane, else stacked below.
# ABOUTME: Lets agents show long-running commands (servers, tests, logs) where the user can watch them.
"""Standard-library-only. Python 3.9 compatible.

Usage: rex-run [--label NAME] [--cwd DIR] [--focus] [--close-on-exit] -- COMMAND...

The pane running rex-run's caller is $REX_BLOCK in $REX_SESSION. When it is
the only pane in its tab, the command opens to its right. Once the tab is split,
each new command stacks below the last command pane, so the caller keeps its
full height. Prints JSON with the new block_id for `rex capture` and `rex wait`."""

import argparse
import json
import os
import shutil
import subprocess
import sys

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


def caller_layout(session_id, caller):
    view = rex("api", "call", "session.view", json.dumps({"session_id": session_id}))
    for window in view["windows"]:
        for layer in window["layers"]:
            if layer.get("kind") != "tiled":
                continue
            if caller in blocks_in_order(layer["layout"]):
                return layer["layout"]
    raise RuntimeError(f"pane {caller} isn't in a tab of session {session_id}")


def run(session_id, caller, command, label=None, cwd=None, focus=False, keep_open=True):
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
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    session_id = os.environ.get("REX_SESSION")
    caller = os.environ.get("REX_BLOCK")
    if not command:
        parser.error("give a command after --")
    if not session_id or not caller:
        print(
            "rex-run: not inside a Rex pane (REX_SESSION/REX_BLOCK unset)",
            file=sys.stderr,
        )
        return 2
    try:
        result = run(
            session_id,
            caller,
            command,
            label=args.label,
            cwd=args.cwd,
            focus=args.focus,
            keep_open=not args.close_on_exit,
        )
    except RuntimeError as err:
        print(f"rex-run: {err}", file=sys.stderr)
        return 1
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
