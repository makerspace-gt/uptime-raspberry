#!/bin/bash
# Backup statistics for uptime-raspberry
# Shows duration, status, and key metrics for sync/check jobs
# Usage: backup-stats.sh [DAYS]   (default: 30)

set -euo pipefail

LOG_DIR=/var/log/backup-sync
DAYS=${1:-30}

fmt_duration() {
    local secs=$1
    local h=$(( secs / 3600 ))
    local m=$(( (secs % 3600) / 60 ))
    local s=$(( secs % 60 ))
    if (( h > 0 )); then
        printf "%dh %02dm %02ds" "$h" "$m" "$s"
    else
        printf "%dm %02ds" "$m" "$s"
    fi
}

# Parse epoch from log filename: type-YYYYMMDD-HHMMSS.log
filename_to_epoch() {
    local fname type=$1 log=$2
    fname=$(basename "$log")
    local raw="${fname#${type}-}"   # 20260406-030553.log
    raw="${raw%.log}"               # 20260406-030553
    local d="${raw%-*}" t="${raw#*-}"
    date -d "${d:0:4}-${d:4:2}-${d:6:2} ${t:0:2}:${t:2:2}:${t:4:2}" +%s 2>/dev/null || echo ""
}

# Pretty label from filename
filename_to_label() {
    local fname type=$1 log=$2
    fname=$(basename "$log")
    local raw="${fname#${type}-}"
    raw="${raw%.log}"
    local d="${raw%-*}" t="${raw#*-}"
    printf "%s-%s-%s %s:%s" "${d:0:4}" "${d:4:2}" "${d:6:2}" "${t:0:2}" "${t:2:2}"
}

# Color helpers (only when stdout is a terminal)
c_ok=""    c_fail=""  c_warn=""  c_dim=""  c_bold=""  c_reset=""
if [[ -t 1 ]]; then
    c_ok="\e[32m" c_fail="\e[31m" c_warn="\e[33m"
    c_dim="\e[2m" c_bold="\e[1m" c_reset="\e[0m"
fi

print_section() {
    local type=$1 label=$2
    local -a durations=()
    local ok_count=0 fail_count=0

    echo -e "${c_bold}── ${label} ──────────────────────────────────────────────────${c_reset}"
    printf "  %-20s  %-8s  %-14s  %s\n" "Started" "Status" "Duration" "Details"
    printf "  %-20s  %-8s  %-14s  %s\n" "-------" "------" "--------" "-------"

    local found=0
    while IFS= read -r log; do
        found=1

        local dt status details="" dur_str="n/a"

        dt=$(filename_to_label "$type" "$log")

        # Determine status
        if grep -q "^ERROR:" "$log" 2>/dev/null; then
            status="FAILED"
            (( fail_count++ )) || true
        elif grep -q "finished at" "$log" 2>/dev/null; then
            status="OK"
            (( ok_count++ )) || true
        else
            status="RUNNING?"
        fi

        # Duration: filename epoch → file mtime
        local t0 t1
        t0=$(filename_to_epoch "$type" "$log")
        t1=$(stat -c %Y "$log" 2>/dev/null || echo "")
        if [[ -n "$t0" && -n "$t1" && "$t1" -gt "$t0" ]]; then
            local secs=$(( t1 - t0 ))
            dur_str=$(fmt_duration "$secs")
            [[ "$status" == "OK" ]] && durations+=("$secs")
        fi

        # Details
        if [[ "$type" == "sync" ]]; then
            # Prefer rclone's own elapsed time line, fall back to transferred
            local elapsed
            elapsed=$(grep "Elapsed time:" "$log" 2>/dev/null | tail -1 | sed 's/.*Elapsed time: //' || true)
            local xfer
            xfer=$(grep -E "^Transferred:|Transferred:" "$log" 2>/dev/null | grep -v "^20" | tail -1 \
                   || grep "Transferred:" "$log" 2>/dev/null | tail -1 || true)
            xfer=$(echo "$xfer" | sed 's/^[^:]*Transferred: */Transferred: /' | sed 's/  */ /g')
            [[ -n "$elapsed" ]] && details="elapsed ${elapsed}" || details="$xfer"
        elif [[ "$type" == "check" ]]; then
            local summary
            summary=$(grep -E "^(no errors|[0-9]+ error|Fatal:)" "$log" 2>/dev/null | head -1 || true)
            [[ -z "$summary" ]] && summary=$(grep -i "checked\|error\|warning" "$log" 2>/dev/null \
                                             | grep -v "^ERROR:" | grep -v "started\|finished" | tail -1 || true)
            details="$summary"
        fi

        # Colorize status
        local sc="$status"
        [[ "$status" == "OK" ]]       && sc="${c_ok}${status}${c_reset}"
        [[ "$status" == "FAILED" ]]   && sc="${c_fail}${status}${c_reset}"
        [[ "$status" == "RUNNING?" ]] && sc="${c_warn}${status}${c_reset}"

        printf "  %-20s  ${sc}%-$((8 - ${#status}))s  %-14s  ${c_dim}%s${c_reset}\n" \
            "$dt" "" "$dur_str" "$details"
    done < <(find "$LOG_DIR" -name "${type}-*.log" -mtime -"$DAYS" | sort)

    if (( found == 0 )); then
        echo "  (no logs found in last ${DAYS} days)"
    fi

    # Statistics summary
    if (( ${#durations[@]} > 0 )); then
        local min=${durations[0]} max=${durations[0]} sum=0
        for d in "${durations[@]}"; do
            (( d < min )) && min=$d
            (( d > max )) && max=$d
            (( sum += d )) || true
        done
        local avg=$(( sum / ${#durations[@]} ))
        echo ""
        echo -e "  ${c_bold}Stats (OK runs):${c_reset}  count=${ok_count}  min=$(fmt_duration $min)  avg=$(fmt_duration $avg)  max=$(fmt_duration $max)"
    fi
    (( fail_count > 0 )) && echo -e "  ${c_fail}Failed runs: ${fail_count}${c_reset}"

    echo ""
}

echo ""
echo -e "${c_bold}Backup Statistics — last ${DAYS} days${c_reset}"
echo "Log directory: ${LOG_DIR}"
echo ""

echo -e "${c_bold}── Repository contents (latest snapshot per host/tags) ──────────${c_reset}"
RESTIC_PW=/opt/backup-sync/restic_password
RESTIC_REPO=/mnt/backup
if command -v restic >/dev/null 2>&1 && [ -r "$RESTIC_PW" ]; then
    restic -r "$RESTIC_REPO" --password-file "$RESTIC_PW" \
        snapshots --latest 1 --group-by host,tags --compact 2>/dev/null \
        || echo "  (failed to query restic repo at $RESTIC_REPO)"
else
    echo "  (restic or $RESTIC_PW unreadable — run this script as root)"
fi
echo ""

print_section "sync"  "rclone Sync"
print_section "check" "restic Check"

echo -e "${c_bold}── Timer status ──────────────────────────────────────────────────${c_reset}"
systemctl list-timers backup-sync.timer backup-check.timer lima-city-backup.timer --no-pager 2>/dev/null || \
    echo "  (systemctl not available or timers not found)"
echo ""

echo -e "${c_bold}── Last journal entries ──────────────────────────────────────────${c_reset}"
journalctl -u backup-sync.service -u backup-check.service -u lima-city-backup.service \
    --since "$(date -d "-${DAYS} days" '+%Y-%m-%d')" \
    --no-pager -q --output=short-iso 2>/dev/null | tail -30 || \
    echo "  (journal unavailable)"
echo ""
