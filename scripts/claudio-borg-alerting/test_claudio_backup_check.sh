#!/usr/bin/env bash
# ABOUTME: Fixture-driven suite for claudio-backup-check.sh covering every branch of its decision table.
# ABOUTME: Substitutes both fetchers and the notifier, so it touches no host and sends no real alert.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/claudio-backup-check.sh"
PASS=0
FAIL=0

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# A stand-in for multica-notify.sh: records "SEVERITY|message" one per line instead of sending.
cat > "$WORK/notify" <<'EOF'
#!/usr/bin/env bash
printf '%s|%s\n' "$1" "$2" >> "$NOTIFY_LOG"
EOF
chmod +x "$WORK/notify"

NOW=1790000000   # fixed clock, so every age in the suite is exact rather than approximately right

iso() { date -u -r "$1" '+%Y-%m-%dT%H:%M:%S+00:00' 2>/dev/null || date -u -d "@$1" '+%Y-%m-%dT%H:%M:%S+00:00'; }

# marker_json SUCCESS_EPOCH RUN_STATUS RUN_EPOCH [ARCHIVE]
marker_json() {
  local se="$1" rs="$2" re="$3" archive="${4:-claudio-box-20260920T140756985817Z}"
  local success run
  if [ "$se" = "none" ]; then success="null"; else
    success="{\"archive\":\"$archive\",\"exit_code\":0,\"finished_at\":\"$(iso "$se")\",\"status\":\"success\"}"
  fi
  run="{\"archive\":\"$archive\",\"exit_code\":$([ "$rs" = failed ] && echo 1 || echo 0),\"finished_at\":\"$(iso "$re")\",\"status\":\"$rs\"}"
  printf '{"schema":1,"host":"claudio-box","now":%s,"last_run":%s,"last_success":%s}' "$NOW" "$run" "$success"
}

# run_case NAME STATE_DIR STATUS_CMD REPO_CMD
run_case() {
  local state="$2" status_cmd="$3" repo_cmd="$4"   # $1 is the case label, kept for readability at the call site
  NOTIFY_LOG="$WORK/log.$$"
  : > "$NOTIFY_LOG"
  OUT="$(NOTIFY_LOG="$NOTIFY_LOG" \
     CLAUDIO_CHECK_STATE_DIR="$state" \
     CLAUDIO_CHECK_CONF=/nonexistent \
     CLAUDIO_CHECK_NOW="$NOW" \
     MULTICA_NOTIFY_CMD="$WORK/notify" \
     CLAUDIO_STATUS_CMD="$status_cmd" \
     CLAUDIO_REPO_CMD="$repo_cmd" \
     bash "$CHECK" 2>&1)"
  SENT="$(cat "$NOTIFY_LOG")"
}

ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n     sent: %s\n     out:  %s\n' "$1" "${SENT:-<nothing>}" "${OUT:-}"; }

expect_sent()     { if grep -qF "$1" <<<"$SENT"; then ok "$2"; else bad "$2"; fi; }
expect_not_sent() { if grep -qF "$1" <<<"$SENT"; then bad "$2"; else ok "$2"; fi; }
expect_silent()   { if [ -z "$SENT" ]; then ok "$1"; else bad "$1"; fi; }

fresh="$((NOW - 3600))"        # 1h  - a normal morning
stale="$((NOW - 40*3600))"     # 40h - past the 36h threshold
grace="$((NOW - 30*3600))"     # 30h - one missed night, inside the grace window

echo "== 1. A normal successful night is silent =="
S="$WORK/s1"; mkdir -p "$S"
run_case n1 "$S" "echo '$(marker_json "$fresh" success "$fresh")'" "echo $fresh"
expect_silent "a healthy backup produces no alert at all"

echo "== 2. The job ran and failed =="
S="$WORK/s2"; mkdir -p "$S"
run_case n2 "$S" "echo '$(marker_json "$fresh" failed "$((NOW - 600))")'" "echo $fresh"
expect_sent "PAGE|The claudio-box nightly Borg backup ran and failed" "a failed run pages"
expect_not_sent "claudio-box backup has stopped" "a failed run does not also fire staleness"

echo "== 3. A later success supersedes an earlier failure =="
run_case n3 "$S" "echo '$(marker_json "$((NOW - 300))" success "$((NOW - 300))")'" "echo $((NOW - 300))"
expect_sent "RESOLVED|The claudio-box nightly Borg backup completed successfully" "recovery sends exactly one RESOLVED"

echo "== 4. Recovery is not sticky: the next pass is silent =="
run_case n4 "$S" "echo '$(marker_json "$((NOW - 300))" success "$((NOW - 300))")'" "echo $((NOW - 300))"
expect_silent "a recovered condition does not keep re-notifying"

echo "== 5. Staleness: the marker has aged past 36h =="
S="$WORK/s5"; mkdir -p "$S"
run_case n5 "$S" "echo '$(marker_json "$stale" success "$stale")'" "echo $stale"
expect_sent "PAGE|The claudio-box backup has stopped" "a stale marker pages"

echo "== 6. One missed night stays inside the grace window =="
S="$WORK/s6"; mkdir -p "$S"
run_case n6 "$S" "echo '$(marker_json "$grace" success "$grace")'" "echo $grace"
expect_silent "30h - one transient miss - does not page"

echo "== 7. claudio-box gone: the last known reading still ages into a page =="
S="$WORK/s7"; mkdir -p "$S"
echo "$stale" > "$S/claudio.last-success-epoch"
run_case n7 "$S" "exit 255" "echo $stale"
expect_sent "PAGE|The claudio-box backup has stopped" "an unreachable host still pages once its last reading is stale"
expect_sent "last known reading" "the page says the figure came from the last reading, not a live one"

echo "== 8. Unreachable claudio-box warns only after a sustained streak =="
S="$WORK/s8"; mkdir -p "$S"
echo "$fresh" > "$S/claudio.last-success-epoch"
run_case n8a "$S" "exit 255" "echo $fresh"
expect_not_sent "Cannot read the backup status markers" "one failed read is a blip, not an alert"
run_case n8b "$S" "exit 255" "echo $fresh"
run_case n8c "$S" "exit 255" "echo $fresh"
expect_sent "WARN|Cannot read the backup status markers on claudio-box" "three consecutive failed reads warn"

echo "== 9. ... and clears when it comes back =="
run_case n9 "$S" "echo '$(marker_json "$fresh" success "$fresh")'" "echo $fresh"
expect_sent "RESOLVED|Backup status markers on claudio-box are readable again" "reachability recovery resolves"

echo "== 10. An orphan pending-* archive can never read as fresh =="
S="$WORK/s10"; mkdir -p "$S"
run_case n10 "$S" "echo '$(marker_json "$fresh" success "$fresh" pending-claudio-box-20260920T133616806216Z)'" "echo $fresh"
expect_sent "which is not a completed claudio-box-* archive" "a pending-* archive in the marker pages"
expect_sent "PAGE|The claudio-box backup has stopped" "and the backup is treated as unproven, not fresh"

echo "== 11. A fresh marker cannot hide a repository that stopped receiving =="
S="$WORK/s11"; mkdir -p "$S"
run_case n11 "$S" "echo '$(marker_json "$fresh" success "$fresh")'" "echo $stale"
expect_sent "nothing has been written to the repository on membrain" "the durable side fires on its own"

echo "== 12. No successful run has ever been recorded =="
S="$WORK/s12"; mkdir -p "$S"
run_case n12 "$S" "echo '$(marker_json none success "$fresh")'" "echo $fresh"
expect_sent "PAGE|claudio-box reports no successful backup on record" "an absent success marker pages"

echo "== 13. A future timestamp is never accepted as freshness =="
S="$WORK/s13"; mkdir -p "$S"
run_case n13 "$S" "echo '$(marker_json "$((NOW + 86400))" success "$fresh")'" "echo $fresh"
expect_sent "timestamped in the future" "clock skew pages instead of silencing the check"

echo "== 14. Garbage from the far end is a transport failure, not a parse crash =="
S="$WORK/s14"; mkdir -p "$S"
echo "$fresh" > "$S/claudio.last-success-epoch"
run_case n14a "$S" "echo 'not json at all'" "echo $fresh"
run_case n14b "$S" "echo 'not json at all'" "echo $fresh"
run_case n14c "$S" "echo 'not json at all'" "echo $fresh"
expect_sent "WARN|Cannot read the backup status markers" "unparseable output is handled like an unreachable host"

echo "== 15. membrain unreachable warns but does not stop the marker side working =="
S="$WORK/s15"; mkdir -p "$S"
run_case n15a "$S" "echo '$(marker_json "$stale" success "$stale")'" "exit 255"
expect_sent "PAGE|The claudio-box backup has stopped" "the marker side still pages when membrain is unreadable"
run_case n15b "$S" "echo '$(marker_json "$stale" success "$stale")'" "exit 255"
run_case n15c "$S" "echo '$(marker_json "$stale" success "$stale")'" "exit 255"
expect_sent "WARN|Cannot read the claudio-box Borg repository on membrain" "sustained membrain unreachability warns"

echo "== 16. An empty repository pages =="
S="$WORK/s16"; mkdir -p "$S"
run_case n16 "$S" "echo '$(marker_json "$fresh" success "$fresh")'" "echo EMPTY"
expect_sent "has no transaction files" "an empty or missing repository pages"

echo "== 17. A sustained page does not re-notify inside its cooldown =="
S="$WORK/s17"; mkdir -p "$S"
run_case n17a "$S" "echo '$(marker_json "$stale" success "$stale")'" "echo $stale"
run_case n17b "$S" "echo '$(marker_json "$stale" success "$stale")'" "echo $stale"
expect_silent "a still-true condition is deduplicated rather than repeated every pass"

echo "== 18. The alert payload carries no raw upstream string =="
S="$WORK/s18"; mkdir -p "$S"
run_case n18 "$S" "echo '$(marker_json "$fresh" success "$fresh" "$(printf 'pending-%0.sA' 1 2 3)$(head -c 400 /dev/zero | tr '\0' 'B')")'" "echo $fresh"
longest="$(awk -F'|' '{print length($2)}' <<<"$SENT" | sort -rn | head -1)"
TRUNC_CASE="an oversized archive name is truncated before it leaves the host"
if [ "${longest:-0}" -lt 600 ]; then ok "$TRUNC_CASE"; else bad "$TRUNC_CASE"; fi

printf '\npassed: %s failed: %s\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
