Nightly Borg capture for claudio-box
==================================

`backup.py` uses Python's standard library for process supervision, JSON status,
locking and cleanup. It invokes the installed SQLite, Dolt and Borg clients.
It runs as root because two OpenViking config files are root-owned mode 0600.
No source permissions are relaxed.

The systemd timer is **installed but disabled** pending an unattended credential
decision. A successful supervised run is not proof of a functioning schedule.
The service currently fails closed because `op` is not installed on claudio-box
and no unattended 1Password identity has been provisioned there.

Capture contract
----------------

* SQLite: `sqlite3 -readonly ... .backup`, followed by `PRAGMA integrity_check`.
* Dolt: SQL calls to the running server at `100.75.168.99:3306`, independently
  for `fitforge` and `second_brain`:
  `CALL DOLT_BACKUP('sync-url', 'file:///run/user/1000/claudio-borg-snapshot/<database>')`.
  Check the returned status is zero. These are separate consistent snapshots,
  not a transaction shared between databases.
* Snapshots occupy a private directory on `/run/user/1000` (tmpfs), never a
  local archive of `.openclaw`. The Dolt server owns its snapshot directories.
* Borg streams `.openclaw`, `.openviking`, the database snapshots and Dolt
  ancillary configuration directly to the stage-1 sub-account repository.
  No gbrain, msgvault or blogwatcher-ui data is included.
* Every nonzero subprocess exit, including a Borg warning, fails the run.
  Archives are named `pending-claudio-box-*` until `borg create` succeeds.
  Failed pending archives are retained for inspection, not reported as success.
* Snapshots are removed on ordinary success, failure, SIGINT and SIGTERM.
  SIGKILL/power loss can leave stale state; an existing snapshot directory
  blocks the next run rather than being overwritten. Inspect it before removal.
* Retention applies only to `claudio-box-*`: 7 daily, 4 weekly, 6 monthly,
  followed by compact. The main Storage Box account is never used.
* Root free space is sampled every 250 ms and checked between stages. A sampled
  value below 2 GiB fails the run; this is evidence of sampled availability,
  not a filesystem reservation or a guarantee about concurrent writers.

Dolt documents the full-state backup procedure (including uncommitted changes
on every branch) in [server backups](https://www.dolthub.com/docs/sql-reference/server/backups/)
and [DOLT_BACKUP](https://www.dolthub.com/docs/sql-reference/version-control/dolt-sql-procedures/#dolt_backup).
The additional config files are preserved as ancillary files; database tables
and history come from the SQL backup, never a copy of the live data directory.
Restore validation belongs to the subsequent rehearsal stage.

Credentials
-----------

The default mode reads the passphrase using `op read` with vault and item IDs.
Empty values fail. The supervised `--passphrase-stdin` mode accepts one line
from a foreground `op read` on the operator machine through SSH stdin. No
passphrase is placed in argv, a script literal or a file. Dolt uses the existing
`.beads-password` through `DOLT_CLI_PASSWORD`, never through a command argument.

The current Borg item is in Private. [1Password service accounts cannot access
that vault](https://www.1password.dev/service-accounts/get-started).
Resolve the credential decision, update the item-ID reference if it moves,
and prove `systemctl start claudio-borg.service` succeeds without an interactive
session before enabling `claudio-borg.timer`.

Monitoring contract
-------------------

* Fixed log: `/var/lib/claudio-borg/backup.log` (root-only, append).
* Last attempt: `/var/lib/claudio-borg/last-run.json`, written at entry with
  `status=running`, then replaced atomically with `status=success` or `failed`.
* Last completed success: `/var/lib/claudio-borg/last-success.json`, replaced
  atomically **only after create, prune and compact all succeed**.
* JSON fields: `schema_version` (1), `started_at`, `finished_at` (UTC ISO 8601),
  `status`, `archive`, `exit_code`, `min_root_free_bytes`, and
  `free_space_sample_interval_seconds` (0.25, added on completion).
* A missing marker means no recorded success/attempt. A newer failed attempt
  identifies a failure; an old success with no newer attempt identifies missed
  execution. A stale `running` record requires checking service/process state.
* An overlapping invocation exits 1 without replacing the active run's marker.
  Errors before state can be opened are available in the systemd journal.

Deployment and validation
-------------------------

Installed code: `/usr/local/lib/claudio-borg/backup.py`, root-owned.
Units: `/etc/systemd/system/claudio-borg.{service,timer}`.
Schedule: 03:00 UTC nightly plus up to 15 minutes jitter, persistent catch-up.
The timer remains disabled until credential provisioning is verified.

Run the integration checks from a machine with the `claudio-box` SSH alias:

```
uv run --with pytest python -m pytest -q scripts/claudio-borg/test_live.py
```

They require a prior successful supervised run. The first test hides the real
SQLite directory only inside a transient systemd mount namespace. The second
asserts the current deployment blocker using the actual service. Both require
nonzero exits and preservation of the last-success marker. No fake data,
credential or executable is substituted. Running them records failed attempts;
the second test should be replaced once credentials are provisioned.

Rollback: leave/disable `claudio-borg.timer` with `systemctl disable --now`.
The source services were never changed. Retain the encrypted repository and
status/evidence files. Previous development script revisions are preserved in
`/usr/local/lib/claudio-borg/backup.py.before-*`; the prior task-created service
is `/etc/systemd/system/claudio-borg.service.before-root-runner`. There were no
pre-existing claudio-borg files to restore before this task.
