# claudio-box backup alerting

Two conditions, one channel. This watches the nightly Borg job built in GAR-46 and says something
when it fails, and — the harder half — when it silently stops running. A backup that quietly stops
is indistinguishable from a working one until the day you need it, and by then the evidence is gone
too.

## Where it runs, and why not on claudio-box

**The checker runs on `garage-multica`.** Deliberately not on `claudio-box`, which is the host it is
watching.

A check that lives only on its subject cannot report that the subject is gone. If `claudio-box` is
powered off, its disk is full, its timer was masked, or systemd never came up, a local checker does
not fire an alert — it fails to run at all, and failing to run looks exactly like having nothing to
say. That is the failure mode this unit exists to catch, so the check has to be somewhere else.

`garage-multica` is a separate Hetzner VPS in a different datacentre, on the same tailnet, and it is
already the fleet's monitoring host: it runs `multica-check.sh` on a 60s timer and owns
`multica-notify.sh`, the Telegram delivery path proven end to end in GAR-25. Putting this check there
adds no new host, no new channel, and no new credential store.

Its own liveness is covered the same way every other check on that host is: `ExecStopPost=` pages if
`claudio-backup-check.service` itself exits non-zero, because a monitor that fails silently converts
"no alerts" from evidence into an assumption.

## The two observation points

Staleness is judged against two places that share nothing with each other. Either one going stale
fires the page, so neither can mask the other.

| | Read from | Survives claudio-box being down? | What it proves |
|---|---|---|---|
| **Success marker** | `/var/lib/claudio-borg/last-success.json` on claudio-box | Yes — via the persisted last reading, below | A run completed |
| **Repository transactions** | `hints.*` mtime under `./claudio-box/backup` on membrain | Yes — reads membrain directly | Something actually landed off-host |

**The marker keeps ageing when the host is gone.** Every successful read persists the marker's epoch
to `/var/lib/multica-monitor/claudio.last-success-epoch`. When claudio-box becomes unreachable the
checker keeps evaluating against that stored figure, which ages on its own, so an unreachable host
still pages as stale once the last known reading passes 36 hours. It does not go quiet — going quiet
when you cannot reach your subject is the exact bug this design is built to avoid. The alert says
`last known reading` rather than `live` so the reader knows which they are looking at.

### Why the repository side is only corroboration

Reading Borg *archive names* needs the repository passphrase. Putting that passphrase on a second
host to satisfy a monitoring check would widen the credential blast radius to buy a signal the
marker already gives us, so we do not. What is readable without it is `hints.N`/`index.N`, which Borg
rewrites on every committed write transaction — that is the last time the repository was written.

That signal cannot tell a completed `claudio-box-*` archive from a half-written `pending-*` one, so
it is never the primary freshness measure. It is used for what it is genuinely good at: catching a
marker that claims success while nothing is reaching membrain. The marker side, meanwhile, catches
the stop that a stray `pending-*` write would hide from the repository side.

An orphan `pending-*` archive can never read as a fresh backup: the checker requires the marker's
archive name to match `^claudio-box-[0-9]{8}T[0-9]+Z$` and pages if it does not.

## Thresholds

| Threshold | Value | Why this number |
|---|---|---|
| `STALE_PAGE_H` | 36h | The job runs at 03:00 UTC with up to 15 minutes of jitter. 24h pages on the normal spread between two runs; 26h pages on one transient miss. 36h is exactly one nightly cycle of grace — a single bad night is absorbed, a genuine stop is caught inside two days. |
| `UNREACHABLE_WARN_STREAK` | 3 | At the 10-minute cadence that is 30 minutes of sustained unreachability. One failed read is a network blip. WARN, not PAGE: unreachability is not yet a lost backup, and if it becomes one the staleness page arrives on its own. |
| `ALERT_COOLDOWN_S` | 21600 (6h) | The condition changes at most once a night. A 30-minute cooldown would emit 48 identical pages before the next run could possibly clear it. Six hours means a sustained outage pages four times a day — enough to not be forgotten, few enough to not be muted. A muted alert is worse than no alert. |
| Timer cadence | 10 min | The threshold is 36 hours, so 10-minute resolution spends 0.5% of the detection budget and cuts two SSH round-trips per minute down to two per ten minutes. |

## Access, and how little of it there is

The checker needs to read two root-owned JSON files on another host. It gets exactly that and
nothing more:

- A dedicated key, `/root/.ssh/claudio-status-ed25519` on garage-multica, used for nothing else.
- On claudio-box that key is pinned in `authorized_keys` with
  `restrict,command="/usr/bin/sudo -n /usr/local/sbin/claudio-borg-status"`. `restrict` disables pty,
  agent, port and X11 forwarding; the forced command means the key can run one program and no other,
  whatever the client asks for. Verified: a client explicitly requesting `cat /etc/shadow` gets the
  backup status JSON back.
- `/usr/local/sbin/claudio-borg-status` reads those two files, allowlists the fields that may leave
  the host, and touches nothing else — not the job, not its log, not its lock.
- `/etc/sudoers.d/92-claudio-borg-status` grants `esttorhe` that one command. `esttorhe` already
  holds blanket NOPASSWD sudo, so this grants nothing new; it exists so the dependency is explicit
  and survives the blanket rule ever being tightened.
- The membrain side reuses the Storage Box key garage-multica already holds for the control-plane
  backup check. **No new credential was created for this unit.**

## Runbook

### `PAGE` — nightly backup failed

The job ran and recorded a failure. `last-success.json` still names the last archive that did
complete; the alert tells you how old it is.

1. `ssh claudio-box 'sudo journalctl -u claudio-borg.service -n 50'`
2. `ssh claudio-box 'sudo tail -40 /var/lib/claudio-borg/backup.log'`
3. **Before treating this as data loss, check whether an archive was nonetheless produced.** GAR-46
   records Borg exit 1 as a hard failure, but per Borg's documentation exit 1 means the operation
   reached its normal end with warnings — errors are exit 2. A single unreadable or mid-change file
   therefore fails a run that captured everything. This has happened: the 13:36 run on 2026-09-20
   captured 42,086 files / 1.90 GB and was still recorded failed, because two
   `~/.openviking/ovcli.conf*` files were briefly unreadable.
4. Fix the cause and run `sudo systemctl start claudio-borg.service`. A later success supersedes the
   failure and the alert resolves itself on the next check.

### `PAGE` — nightly backup stale

Nothing is failing loudly; the job is simply not producing recovery points. The alert names which
side went stale.

1. Is the job scheduled at all? `ssh claudio-box 'systemctl list-timers claudio-borg.timer'`. If
   `UnitFileState` is not `enabled`, that is the answer — `systemctl enable --now claudio-borg.timer`.
2. Is the host up? If the alert says `last known reading`, the checker could not reach claudio-box.
3. Did anything land on membrain? If the alert also names the repository, nothing has been written
   there, and the problem is the push, not the schedule — check credentials and the Storage Box.
4. Run one by hand: `ssh claudio-box 'sudo systemctl start claudio-borg.service'`.

### `PAGE` — success marker names a non-final archive

The marker names a `pending-*` archive, which GAR-46 only renames on success. Either a run is being
recorded wrongly or the marker was edited. Do not treat the backup as fresh. Read the marker and the
job's recent history before doing anything else.

### `PAGE` — marker timestamped in the future

Clock skew between garage-multica and claudio-box. Fix the clock before trusting any backup age —
a future timestamp is how a real stop gets silenced.

### `WARN` — claudio-box status unreadable / membrain unreachable

Transport, not backup. Check the tailnet (`tailscale status`) or the Storage Box. Backup state is
still being judged, against the last reading, and will page as stale on its own if it goes cold.

## Rollback

Nothing here is destructive, and every piece is independently removable.

```
# Stop watching (the backup itself is unaffected)
ssh garage-multica 'systemctl disable --now claudio-backup-check.timer'

# Remove the checker entirely
ssh garage-multica 'rm -f /usr/local/sbin/claudio-backup-check.sh \
    /etc/systemd/system/claudio-backup-check.{service,timer} \
    /etc/multica-monitor/claudio-backup.conf; systemctl daemon-reload'

# Revoke the access it was granted
ssh claudio-box 'sudo sed -i "/garage-multica-backup-status/d" /home/esttorhe/.ssh/authorized_keys
                 sudo rm -f /etc/sudoers.d/92-claudio-borg-status /usr/local/sbin/claudio-borg-status'
ssh garage-multica 'rm -f /root/.ssh/claudio-status-ed25519*'

# Undo the delivery-receipt line added to the notifier
ssh garage-multica 'cp -a /usr/local/sbin/multica-notify.sh.before-gar49-20260920 \
                          /usr/local/sbin/multica-notify.sh'
```

## Tests

`./test_claudio_backup_check.sh` — 23 cases, no host contact, no real alert sent. Both fetchers and
the notifier are substituted, so the whole decision table runs on a laptop. It earned its place
immediately: it caught that `${ARCHIVE_PATTERN:-^claudio-box-[0-9]{8}T[0-9]+Z$}` silently truncates
at the first `}`, leaving a pattern that matches nothing and pages on every healthy night.

## Install

Checker host (garage-multica):

```
install -m 0700 claudio-backup-check.sh          /usr/local/sbin/
install -m 0644 claudio-backup-check.service     /etc/systemd/system/
install -m 0644 claudio-backup-check.timer       /etc/systemd/system/
install -m 0644 claudio-backup.conf.example      /etc/multica-monitor/claudio-backup.conf
ssh-keygen -t ed25519 -N '' -f /root/.ssh/claudio-status-ed25519
ssh-keyscan -t ed25519 <claudio-box-ip> > /root/.ssh/claudio-status-known-hosts   # verify the
                                                                                  # fingerprint
systemctl daemon-reload && systemctl enable --now claudio-backup-check.timer
```

Watched host (claudio-box): install `claudio-borg-status` to `/usr/local/sbin/` mode 0755, add the
sudoers line, and append the public key to `authorized_keys` with the `restrict,command=` prefix
shown above.
