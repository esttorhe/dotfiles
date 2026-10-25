# rex-resurrect

tmux-resurrect and tmux-continuum, for [Rex](https://www.superlogical.com/rex/docs).
It saves every Rex session and restores it after the Rex server restarts
(a reboot, a crash, or quitting the app).

## What is saved

| Saved | Restored as |
| --- | --- |
| Sessions, tab names, split tree and ratios, pane labels | The same layout |
| Each pane's working directory | A shell started in that directory |
| `nvim`, `vim`, `vi`, `lazygit`, `yazi`, `htop`, `btop`, `top` | The program typed into that shell |
| `claude` | `claude --resume '<session name>'` from the pane title, else `claude --continue` |

Rex reports a program's name but not its arguments, so `nvim foo.py` comes
back as `nvim`. Scrollback and floating layers aren't saved. A session that
is only one idle shell in the home directory (the one the app opens on start)
is left out, so restarts don't pile them up.

## How it runs

- `com.esttorhe.rex-resurrect` (launchd) runs `rex-resurrect tick` at login
  and every five minutes. A tick restores the last snapshot once for each new
  Rex server, then saves. Until that restore has happened, scheduled saves
  are refused, so an empty server never overwrites the snapshot it should
  restore. Sessions whose label is already open are never recreated.
- In Rex, `Ctrl-X Ctrl-S` saves now and `Ctrl-X Ctrl-R` restores the last
  snapshot. Both are also in the command palette.
- The script never starts a Rex server. With the app closed, a tick exits 1
  and logs that no server is running.

## Files

| Path | What |
| --- | --- |
| `~/.local/state/rex-resurrect/last.json` | The snapshot a restore uses |
| `~/.local/state/rex-resurrect/snapshots/` | The newest 50 snapshots |
| `~/.local/state/rex-resurrect/state.json` | The server instance already restored |
| `~/Library/Logs/rex-resurrect/` | launchd output |

Restore an older snapshot with
`rex-resurrect restore --snapshot ~/.local/state/rex-resurrect/snapshots/<file>`.
Add `--no-start` to type each program's command at its prompt without
running it.

## Moving from tmux

`rex-resurrect import-tmux --output FILE` writes every tmux session, window,
split and directory as a snapshot. Both tmux layout formats are read: the
classic string and the JSON newer servers report. A Claude pane titled
`✳ name` becomes `claude --resume 'name'`; an unnamed one opens Claude's
resume picker, since several panes can share a directory. Then:

```sh
rex-resurrect import-tmux --output /tmp/tmux.json
rex-resurrect restore --snapshot /tmp/tmux.json --no-start
```

With `--no-start`, a conversation still open in tmux isn't resumed twice:
press Enter in each Rex pane once its tmux pane is closed.

## Tests

The tests use the live local Rex server with disposable `rrtest-` sessions
and a temporary state directory:

```sh
uv run --python 3.9 --with pytest pytest -q -p no:cacheprovider
```
