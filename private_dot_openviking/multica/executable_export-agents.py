#!/usr/bin/env python3
# ABOUTME: Exports live Multica agents to per-agent instruction files plus a manifest.
# ABOUTME: The workspace is the source of truth; these files are the reproducible form of it.

"""
Export Multica agents -> ~/.openviking/multica/agents/

Why this exists
---------------
Agent instructions live in Postgres, which no dotfiles manager can carry. Hand-kept
copies drift the moment anyone edits an agent in the UI -- by the time this was
written, five hand-written files had diverged from their live agents (one by 4x)
and six agents had no file at all.

So the direction is live -> files, never the reverse. Run this after changing an
agent; commit the result. `bootstrap.py` replays it onto an empty workspace.

The manifest carries what the instructions cannot: provider, model, reasoning
level, concurrency. Runtime IDs are deliberately NOT stored -- they are specific
to one machine's daemon, so the bootstrap resolves them by provider instead.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys

AGENTS_DIR = os.path.expanduser("~/.openviking/multica/agents")
MANIFEST = os.path.join(AGENTS_DIR, "manifest.json")


def mc_json(*args: str):
    proc = subprocess.run(["multica", *args, "--output", "json"],
                          capture_output=True, text=True, timeout=120)
    if proc.returncode != 0:
        raise SystemExit(f"multica {' '.join(args[:2])} failed: {proc.stderr.strip()[:300]}")
    return json.loads(proc.stdout)


def slug(name: str) -> str:
    """Stable filename from an agent name.

    Agent names carry em dashes and parentheses ("Oksana — Security (Pentest &
    SOC 2)"). Those are fine in a manifest value but poor in a filename, so
    reduce to lowercase words joined by hyphens.
    """
    cleaned = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
    return cleaned or "agent"


def main() -> None:
    os.makedirs(AGENTS_DIR, exist_ok=True)

    runtimes = {r["id"]: r["provider"] for r in mc_json("runtime", "list")}

    listing = mc_json("agent", "list")
    agents = listing.get("agents", listing) if isinstance(listing, dict) else listing

    manifest = []
    written = []
    for row in agents:
        agent = mc_json("agent", "get", row["id"])
        if agent.get("archived_at"):
            continue

        name = agent["name"]
        filename = f"{slug(name)}.md"
        instructions = agent.get("instructions") or ""

        path = os.path.join(AGENTS_DIR, filename)
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(instructions.rstrip() + "\n")
        written.append((filename, len(instructions)))

        manifest.append({
            "name": name,
            "description": agent.get("description") or "",
            "provider": runtimes.get(agent.get("runtime_id"), ""),
            "model": agent.get("model") or "",
            "thinking_level": agent.get("thinking_level") or "",
            "max_concurrent_tasks": agent.get("max_concurrent_tasks") or 6,
            "permission_mode": agent.get("permission_mode") or "private",
            "instructions_file": filename,
        })

    manifest.sort(key=lambda entry: entry["name"])
    with open(MANIFEST, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2, ensure_ascii=False)
        handle.write("\n")

    print(f"exported {len(manifest)} agents -> {AGENTS_DIR}")
    for filename, size in sorted(written):
        print(f"  {filename:<40} {size:>6}b")
    missing = [e["name"] for e in manifest if not e["provider"]]
    if missing:
        print(f"\nwarning: no provider resolved for: {missing}", file=sys.stderr)


if __name__ == "__main__":
    main()
