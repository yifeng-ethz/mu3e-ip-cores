#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  watch_feb_quartus_compile.sh [--dir <proj_dir>] [--project <name>] [--rev <rev>] [--interval-sec <sec>] [--log <file>]

Purpose:
  Run the FEB Quartus compile with a long-period heartbeat and a completion
  notification. Default heartbeat is 1800 s (30 min), matching the current
  debug workflow.
EOF
}

proj_dir="/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/board_projects/fe_scifi_feb_v3"
project="top"
rev="top"
interval_sec="${WATCH_INTERVAL_SEC:-1800}"
console_log=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dir)
            proj_dir="$2"
            shift 2
            ;;
        --project)
            project="$2"
            shift 2
            ;;
        --rev)
            rev="$2"
            shift 2
            ;;
        --interval-sec)
            interval_sec="$2"
            shift 2
            ;;
        --log)
            console_log="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if ! [[ "${interval_sec}" =~ ^[0-9]+$ ]] || [ "${interval_sec}" -lt 0 ]; then
    echo "ERROR: --interval-sec must be a non-negative integer (got '${interval_sec}')" >&2
    exit 2
fi

cd -- "${proj_dir}"

if [ -z "${console_log}" ]; then
    console_log="quartus_compile_${rev}.console.log"
fi

if ! command -v quartus_sh >/dev/null 2>&1; then
    echo "ERROR: quartus_sh not found in PATH" >&2
    exit 2
fi

qsf_file="${project}.qsf"
output_dir="output_files"
if [ -f "${qsf_file}" ]; then
    output_dir_parsed="$(awk -F '\"' '/PROJECT_OUTPUT_DIRECTORY/ {print $2; exit}' "${qsf_file}" || true)"
    if [ -n "${output_dir_parsed}" ]; then
        output_dir="${output_dir_parsed}"
    fi
fi

echo "WATCH_QUARTUS_DIR          : $(pwd)"
echo "WATCH_QUARTUS_PROJECT      : ${project}"
echo "WATCH_QUARTUS_REVISION     : ${rev}"
echo "WATCH_QUARTUS_OUTPUT_DIR   : ${output_dir}"
echo "WATCH_QUARTUS_INTERVAL_SEC : ${interval_sec}"
echo "WATCH_QUARTUS_CONSOLE_LOG  : ${console_log}"

start_ts="$(date +%s)"

watch_tail_reports() {
    local newest=""
    local candidates=(
        "${output_dir}/${rev}.fit.rpt"
        "${output_dir}/${rev}.map.rpt"
        "${output_dir}/${rev}.sta.rpt"
        "${output_dir}/${rev}.flow.rpt"
    )

    for f in "${candidates[@]}"; do
        if [ -f "${f}" ]; then
            if [ -z "${newest}" ]; then
                newest="${f}"
            elif [ "${f}" -nt "${newest}" ]; then
                newest="${f}"
            fi
        fi
    done

    if [ -z "${newest}" ]; then
        echo "WATCH_QUARTUS_STATUS       : no report files yet"
        return 0
    fi

    echo "WATCH_QUARTUS_STATUS       : newest_report=${newest}"
    stat -c "WATCH_QUARTUS_REPORT_MTIME : %y (bytes=%s)" "${newest}" 2>/dev/null || true
    echo "WATCH_QUARTUS_REPORT_TAIL  : begin"
    tail -n 8 "${newest}" 2>/dev/null || true
    echo "WATCH_QUARTUS_REPORT_TAIL  : end"
}

notify_done() {
    local rc="$1"
    local msg="FEB Quartus compile ${rev} finished rc=${rc}"
    printf '\a'
    echo "WATCH_QUARTUS_NOTIFY       : ${msg}"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Codex FEB compile" "${msg}" || true
    fi
}

heartbeat_pid=""
if [ "${interval_sec}" -gt 0 ]; then
    (
        while true; do
            sleep "${interval_sec}"
            now_ts="$(date +%s)"
            elapsed_s="$((now_ts - start_ts))"
            echo "WATCH_QUARTUS_HEARTBEAT    : $(date +%F_%T) elapsed_s=${elapsed_s}"
            watch_tail_reports || true
        done
    ) &
    heartbeat_pid="$!"
fi

cleanup() {
    if [ -n "${heartbeat_pid}" ]; then
        kill "${heartbeat_pid}" 2>/dev/null || true
    fi
}
trap cleanup EXIT

set +e
quartus_sh --flow compile "${project}" -c "${rev}" 2>&1 | tee "${console_log}"
rc="${PIPESTATUS[0]}"
set -e

cleanup
trap - EXIT

echo "WATCH_QUARTUS_DONE         : rc=${rc}"
if [ -f "${output_dir}/${rev}.sta.summary" ]; then
    echo "WATCH_QUARTUS_STA_SUMMARY  : ${output_dir}/${rev}.sta.summary"
    sed -n '1,30p' "${output_dir}/${rev}.sta.summary" || true
fi
if [ -f "${output_dir}/${rev}.fit.summary" ]; then
    echo "WATCH_QUARTUS_FIT_SUMMARY  : ${output_dir}/${rev}.fit.summary"
    cat "${output_dir}/${rev}.fit.summary" || true
fi

notify_done "${rc}"
exit "${rc}"
