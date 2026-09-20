#!/usr/bin/env bash
# ABOUTME: Alerts when the claudio-box nightly Borg backup fails or silently stops running.
# ABOUTME: Runs off claudio-box so it can still report that claudio-box is the thing that is gone.
set -euo pipefail

# --- Overridable roots and fetchers. Defaults are the real host paths and transports; the test
# --- suite points them at fixtures so the whole decision table runs without touching a host.
STATE_DIR="${CLAUDIO_CHECK_STATE_DIR:-/var/lib/multica-monitor}"
CONF_FILE="${CLAUDIO_CHECK_CONF:-/etc/multica-monitor/claudio-backup.conf}"
NOTIFY_CMD="${MULTICA_NOTIFY_CMD:-/usr/local/sbin/multica-notify.sh}"

# --- Thresholds. Each is derived here, not copied from anywhere. ---

# 36 hours, from the issue and for the reason stated there: the job runs nightly at 03:00 UTC with
# up to 15 minutes of jitter, so 24h would page on the normal spread between two runs and 26h would
# page on one transient miss. 36h gives exactly one nightly cycle of grace, so a single bad night is
# absorbed and a genuine stop is still caught inside two days. Anything larger starts trading away
# the only thing this check exists to buy: finding out before the restore does.
STALE_PAGE_H="${STALE_PAGE_H:-36}"

# A read failure that lasts one evaluation is a network blip, not an incident. Three consecutive
# failures at the 600s cadence is 30 minutes of sustained unreachability, which is worth saying out
# loud. It is a WARN and not a PAGE on purpose: unreachability is not yet a lost backup, and if it
# really is one, the staleness PAGE below arrives on its own once the last known good read ages out.
UNREACHABLE_WARN_STREAK="${UNREACHABLE_WARN_STREAK:-3}"

# Re-notify cadence while a condition persists. The condition here changes at most once a day, so a
# 30-minute cooldown would emit 48 identical pages before the next run could possibly clear it. Six
# hours means a sustained outage pages four times a day: enough to not be forgotten, few enough to
# not be muted. A muted alert is worse than no alert.
ALERT_COOLDOWN_S="${ALERT_COOLDOWN_S:-21600}"

# Hard ceiling on any single value interpolated into an alert. These payloads cross the public
# internet to Telegram; nothing whose shape we do not control goes into one unbounded.
ALERT_FIELD_MAX="${ALERT_FIELD_MAX:-120}"

# The archive names a successful run is allowed to claim. GAR-46 renames an archive out of
# `pending-*` only on success, so a marker naming a `pending-*` archive is either a bug or a
# hand-edited file - and an orphan `pending-*` must never be able to read as a fresh backup.
# Not written as a ${VAR:-default}: parameter expansion ends at the first `}`, which silently
# truncates the {8} quantifier and leaves a pattern that matches nothing. The test suite caught
# exactly that, which is the argument for having one.
if [ -z "${ARCHIVE_PATTERN:-}" ]; then
  ARCHIVE_PATTERN='^claudio-box-[0-9]{8}T[0-9]+Z$'
fi

# --- Transport. Both are commands so the suite can substitute fixtures. ---
CLAUDIO_SSH_HOST="${CLAUDIO_SSH_HOST:-}"
CLAUDIO_SSH_IDENTITY="${CLAUDIO_SSH_IDENTITY:-/root/.ssh/claudio-status-ed25519}"
CLAUDIO_SSH_KNOWN_HOSTS="${CLAUDIO_SSH_KNOWN_HOSTS:-/root/.ssh/claudio-status-known-hosts}"
REPO_SSH_HOST="${REPO_SSH_HOST:-}"
REPO_SSH_PORT="${REPO_SSH_PORT:-23}"
REPO_SSH_IDENTITY="${REPO_SSH_IDENTITY:-/root/.ssh/multica-backup-ed25519}"
REPO_SSH_KNOWN_HOSTS="${REPO_SSH_KNOWN_HOSTS:-/root/.ssh/multica-backup-known-hosts}"
# Borg rewrites hints.N/index.N/integrity.N on every committed write transaction, so their mtime is
# the last time this repository was actually written. Deliberately NOT the newest archive name:
# reading archive names needs the repository passphrase, and putting that passphrase on a second
# host to satisfy a monitoring check would widen the credential blast radius to buy a signal the
# marker already gives us. See README.md, "Why the repository side is only corroboration".
REPO_PATH="${REPO_PATH:-./claudio-box/backup}"

# shellcheck source=/dev/null
if [ -r "$CONF_FILE" ]; then . "$CONF_FILE"; fi

mkdir -p "$STATE_DIR"
NOW="${CLAUDIO_CHECK_NOW:-$(date -u +%s)}"
ALERTS_RAISED=0

# --- Helpers, deliberately identical in behaviour to multica-check.sh. Dedup is per key: an active
# --- alert re-sends only after the cooldown, and clearing a key sends exactly one RESOLVED.
notify() {
  local sev="$1" key="$2" msg="$3" cooldown="${4:-$ALERT_COOLDOWN_S}"
  local stamp="$STATE_DIR/alert.$key"
  ALERTS_RAISED=$((ALERTS_RAISED + 1))
  if [ -f "$stamp" ]; then
    local last; last="$(cat "$stamp")"
    [ $((NOW - last)) -lt "$cooldown" ] && return 0
  fi
  echo "$NOW" > "$stamp"
  "$NOTIFY_CMD" "$sev" "$msg"
}

clear_alert() {
  local key="$1" msg="$2"
  local stamp="$STATE_DIR/alert.$key"
  if [ -f "$stamp" ]; then
    rm -f "$stamp"
    "$NOTIFY_CMD" RESOLVED "$msg"
  fi
  return 0
}

safe_field() {
  printf '%s' "${1:-}" \
    | tr -d '\000-\010\013\014\016-\037\177' \
    | tr '\n\r\t' '   ' \
    | cut -c1-"${2:-$ALERT_FIELD_MAX}"
}

bump_streak() {
  local key="$1" n
  n=$(( $(cat "$STATE_DIR/streak.$key" 2>/dev/null || echo 0) + 1 ))
  echo "$n" > "$STATE_DIR/streak.$key"
  echo "$n"
}
reset_streak() { rm -f "$STATE_DIR/streak.$1"; }

hours_since() { echo $(( (NOW - $1) / 3600 )); }

# The markers carry ISO-8601 with an offset, e.g. 2026-09-20T14:08:12+00:00. GNU date reads that
# directly; BSD date has no -d and its %z rejects the colon inside the offset. Supporting both keeps
# the test suite runnable on a laptop, which is the only reason the {8} quantifier bug above was
# ever found. Returns 0 - never a partial parse - so callers can fail closed on an unreadable time.
to_epoch() {
  local ts="${1:-}" out
  [ -n "$ts" ] || { echo 0; return; }
  if out="$(date -u -d "$ts" +%s 2>/dev/null)"; then echo "$out"; return; fi
  ts="$(printf '%s' "$ts" | sed -E 's/([+-][0-9]{2}):([0-9]{2})$/\1\2/; s/Z$/+0000/')"
  if out="$(date -u -j -f '%Y-%m-%dT%H:%M:%S%z' "$ts" +%s 2>/dev/null)"; then echo "$out"; return; fi
  echo 0
}

# --- Fetchers ---------------------------------------------------------------------------------

# Reaches claudio-box over the tailnet. The key on the other end is pinned to a forced command that
# can only print the two markers, so a compromise of this host yields backup status and nothing else.
fetch_status() {
  if [ -n "${CLAUDIO_STATUS_CMD:-}" ]; then eval "$CLAUDIO_STATUS_CMD"; return; fi
  [ -n "$CLAUDIO_SSH_HOST" ] || return 1
  ssh -i "$CLAUDIO_SSH_IDENTITY" \
      -o IdentitiesOnly=yes -o BatchMode=yes -o PasswordAuthentication=no \
      -o KbdInteractiveAuthentication=no -o StrictHostKeyChecking=yes \
      -o UserKnownHostsFile="$CLAUDIO_SSH_KNOWN_HOSTS" \
      -o ConnectTimeout=15 -o ServerAliveInterval=15 -o ServerAliveCountMax=2 \
      "$CLAUDIO_SSH_HOST" 2>/dev/null
}

# Reaches the Storage Box directly. This path shares nothing with claudio-box, which is the point:
# it still answers when claudio-box is powered off.
fetch_repo_mtime() {
  if [ -n "${CLAUDIO_REPO_CMD:-}" ]; then eval "$CLAUDIO_REPO_CMD"; return; fi
  [ -n "$REPO_SSH_HOST" ] || return 1
  ssh -p "$REPO_SSH_PORT" -i "$REPO_SSH_IDENTITY" \
      -o IdentitiesOnly=yes -o BatchMode=yes -o PasswordAuthentication=no \
      -o KbdInteractiveAuthentication=no -o StrictHostKeyChecking=yes \
      -o UserKnownHostsFile="$REPO_SSH_KNOWN_HOSTS" \
      -o ConnectTimeout=20 -o ServerAliveInterval=15 -o ServerAliveCountMax=2 \
      "$REPO_SSH_HOST" "stat -c %Y $REPO_PATH/hints.* 2>/dev/null || echo EMPTY" 2>/dev/null
}

# --- Observation 1: the success marker on claudio-box -------------------------------------------
#
# MARKER_EPOCH is the finish time of the last fully successful run, or 0 if we could not establish
# one this pass. It is persisted, and the persisted value is what ages: that is what turns "the host
# is gone" into a staleness page instead of into silence. A checker that simply goes quiet when it
# cannot reach its subject is the failure mode this whole unit exists to prevent.
MARKER_EPOCH=0
MARKER_SOURCE="unknown"
RUN_FAILED=0
RUN_DETAIL=""

read_marker() {
  local raw last_epoch run_epoch run_status archive
  if ! raw="$(fetch_status)" || [ -z "$raw" ] || ! jq -e . <<<"$raw" >/dev/null 2>&1; then
    local streak; streak="$(bump_streak claudio.status)"
    if [ "$streak" -ge "$UNREACHABLE_WARN_STREAK" ]; then
      notify WARN claudio.status "Cannot read the backup status markers on claudio-box for ${streak} consecutive checks. Backup state is now being judged only on the last reading, which will page as stale once it passes ${STALE_PAGE_H}h. See runbook: claudio-box status unreadable."
    fi
    return 1
  fi
  reset_streak claudio.status
  clear_alert claudio.status "Backup status markers on claudio-box are readable again."

  archive="$(jq -r '.last_success.archive // empty' <<<"$raw")"
  last_epoch="$(jq -r '.last_success.finished_at // empty' <<<"$raw")"
  if [ -z "$last_epoch" ] || [ -z "$archive" ]; then
    notify PAGE claudio.marker "claudio-box reports no successful backup on record. Either the job has never completed or its success marker was lost. There is nothing to restore from that this check can see."
    return 0
  fi
  if ! [[ "$archive" =~ $ARCHIVE_PATTERN ]]; then
    # An orphan pending-* archive must never be able to read as a fresh backup - that is precisely
    # how a stopped backup hides behind a half-written one.
    notify PAGE claudio.marker "The claudio-box success marker names archive '$(safe_field "$archive" 80)', which is not a completed claudio-box-* archive. Treating the backup as unproven. See runbook: success marker names a non-final archive."
    return 0
  fi
  last_epoch="$(to_epoch "$last_epoch")"
  if ! [[ "$last_epoch" =~ ^[0-9]+$ ]] || [ "$last_epoch" -eq 0 ]; then
    notify PAGE claudio.marker "The claudio-box success marker carries an unparseable finish time. Backup freshness cannot be established."
    return 0
  fi
  if [ "$last_epoch" -gt "$((NOW + 900))" ]; then
    # Never accept a future timestamp as freshness; that is how a clock skew silences a real stop.
    notify PAGE claudio.marker "The claudio-box success marker is timestamped in the future. Check clock consistency between the hosts before trusting any backup age."
    return 0
  fi
  clear_alert claudio.marker "The claudio-box success marker is well-formed again."

  MARKER_EPOCH="$last_epoch"
  MARKER_SOURCE="live"
  echo "$last_epoch" > "$STATE_DIR/claudio.last-success-epoch"

  # Condition 1: the job ran and failed. A failure only counts while it is the most recent outcome -
  # a later success supersedes it, which is what makes the recovery path self-clearing.
  run_status="$(jq -r '.last_run.status // empty' <<<"$raw")"
  run_epoch="$(jq -r '.last_run.finished_at // empty' <<<"$raw")"
  run_epoch="$(to_epoch "$run_epoch")"
  if [ "$run_status" = "failed" ] && [ "$run_epoch" -gt "$last_epoch" ]; then
    RUN_FAILED=1
    RUN_DETAIL="exit $(safe_field "$(jq -r '.last_run.exit_code // "?"' <<<"$raw")" 8) at $(safe_field "$(jq -r '.last_run.finished_at // "?"' <<<"$raw")" 40)"
  fi
  return 0
}

# --- Observation 2: the repository on membrain --------------------------------------------------
REPO_EPOCH=0

read_repo() {
  local raw newest
  if ! raw="$(fetch_repo_mtime)" || [ -z "$raw" ]; then
    local streak; streak="$(bump_streak claudio.repo)"
    if [ "$streak" -ge "$UNREACHABLE_WARN_STREAK" ]; then
      notify WARN claudio.repo "Cannot read the claudio-box Borg repository on membrain for ${streak} consecutive checks. Backup durability is unverifiable from this side; only the marker on claudio-box is still being trusted. See runbook: membrain unreachable."
    fi
    return 1
  fi
  # We got an answer, so membrain is reachable - clear the transport alert before judging content.
  # The EMPTY sentinel is what separates "the repository has no transactions" from "we could not
  # ask"; without it a missing repository and an unreachable Storage Box look identical from here.
  reset_streak claudio.repo
  clear_alert claudio.repo "The claudio-box Borg repository on membrain is readable again."
  newest="$(printf '%s\n' "$raw" | grep -E '^[0-9]+$' | sort -rn | head -1)"
  if [ -z "$newest" ]; then
    notify PAGE claudio.repo.empty "The claudio-box Borg repository on membrain has no transaction files. The repository is empty or has been removed; there is nothing on the durable side to restore from."
    return 0
  fi
  clear_alert claudio.repo.empty "The claudio-box Borg repository on membrain has transactions again."
  [ "$newest" -gt "$((NOW + 900))" ] && newest="$NOW"
  REPO_EPOCH="$newest"
  return 0
}

# --- The two conditions -------------------------------------------------------------------------

evaluate() {
  local marker_age repo_age stale=0 reason=""

  if [ "$MARKER_EPOCH" -eq 0 ] && [ -r "$STATE_DIR/claudio.last-success-epoch" ]; then
    MARKER_EPOCH="$(cat "$STATE_DIR/claudio.last-success-epoch")"
    MARKER_SOURCE="last known reading"
  fi

  # Condition 1: the job ran and failed.
  if [ "$RUN_FAILED" -eq 1 ]; then
    notify PAGE claudio.backup.failure "The claudio-box nightly Borg backup ran and failed ($(safe_field "$RUN_DETAIL")). The last archive that did complete is $(hours_since "$MARKER_EPOCH")h old. See runbook: nightly backup failed. NOTE: GAR-46 records a Borg warning (exit 1) as a hard failure, so this can fire on a night that nonetheless produced a good archive - check the repository before treating it as data loss."
  else
    clear_alert claudio.backup.failure "The claudio-box nightly Borg backup completed successfully."
  fi

  # Condition 2: the job never ran at all, seen from two independent places. Either side going stale
  # fires, and neither can mask the other: the marker side catches a stop that an orphan pending-*
  # write would hide from the repository side, and the repository side catches a marker that claims
  # success while nothing is landing on membrain.
  if [ "$MARKER_EPOCH" -eq 0 ]; then
    stale=1
    reason="no successful backup has ever been observed by this check"
  else
    marker_age="$(hours_since "$MARKER_EPOCH")"
    [ "$marker_age" -ge "$STALE_PAGE_H" ] && { stale=1; reason="the last successful run finished ${marker_age}h ago (${MARKER_SOURCE})"; }
  fi
  if [ "$REPO_EPOCH" -gt 0 ]; then
    repo_age="$(hours_since "$REPO_EPOCH")"
    if [ "$repo_age" -ge "$STALE_PAGE_H" ]; then
      stale=1
      reason="${reason:+$reason; }nothing has been written to the repository on membrain for ${repo_age}h"
    fi
  fi

  if [ "$stale" -eq 1 ]; then
    notify PAGE claudio.backup.stale "The claudio-box backup has stopped: ${reason} (page at ${STALE_PAGE_H}h). Nothing is failing loudly - the job is simply not producing recovery points. See runbook: nightly backup stale."
  else
    clear_alert claudio.backup.stale "The claudio-box backup is producing recovery points again (newest $(hours_since "$MARKER_EPOCH")h old)."
  fi

  printf 'claudio-backup: marker_epoch=%s marker_source=%s marker_age_h=%s repo_epoch=%s repo_age_h=%s run_failed=%s stale=%s alerts_raised=%s\n' \
    "$MARKER_EPOCH" "$MARKER_SOURCE" \
    "$([ "$MARKER_EPOCH" -gt 0 ] && hours_since "$MARKER_EPOCH" || echo -)" \
    "$REPO_EPOCH" \
    "$([ "$REPO_EPOCH" -gt 0 ] && hours_since "$REPO_EPOCH" || echo -)" \
    "$RUN_FAILED" "$stale" "$ALERTS_RAISED"
}

main() {
  # Neither fetcher is allowed to abort the pass: each failure is itself a finding, and a checker
  # that exits early on a transport error stops evaluating the condition it exists to evaluate.
  read_marker || true
  read_repo || true
  evaluate
}

main "$@"
