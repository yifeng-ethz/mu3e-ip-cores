#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_DIR="$(realpath -m -- "${SCRIPT_DIR}/../..")"
REPORT_DIR="${SYSTEM_DIR}/tb_int/REPORT"
DISLIN_DIR="${DISLIN_DIR:-}"

INTERVAL_CSV="${1:?usage: render_type0_rate_dislin.sh <intervals.csv> <summary.csv> [case_name] [output_prefix]}"
SUMMARY_CSV="${2:?usage: render_type0_rate_dislin.sh <intervals.csv> <summary.csv> [case_name] [output_prefix]}"
CASE_NAME="${3:-type0_rate_1000k_allch}"
if [[ $# -ge 4 ]]; then
    OUT_PREFIX="$4"
else
    base="$(basename -- "${INTERVAL_CSV}")"
    OUT_PREFIX="${REPORT_DIR}/${base%_intervals.csv}_type0_rate_dislin"
fi

find_dislin_dir() {
    local candidates=()
    if [[ -n "${DISLIN_DIR}" ]]; then
        candidates+=("${DISLIN_DIR}")
    fi
    candidates+=(
        "/home/yifeng/packages/lib/dislin"
        "/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/packet_scheduler/.vendor/dislin"
        "/home/yifeng/packages/dislin-11.5/examples"
    )
    for candidate in "${candidates[@]}"; do
        if [[ -f "${candidate}/dislin.h" ]] && { [[ -f "${candidate}/libdislin.so" ]] || [[ -f "${candidate}/libdislin.a" ]]; }; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    done
    echo "DISLIN headers/library not found; set DISLIN_DIR" >&2
    return 1
}

DISLIN_DIR="$(find_dislin_dir)"
BUILD_DIR="${REPORT_DIR}/dislin_work/type0_rate"
BIN="${BUILD_DIR}/type0_rate_dislin"
LOG="${OUT_PREFIX}.log"
PNG="${OUT_PREFIX}.png"
PDF="${OUT_PREFIX}.pdf"

mkdir -p "${BUILD_DIR}" "$(dirname -- "${OUT_PREFIX}")"

gcc -O2 -Wall -Wextra -std=c11 \
    -I"${DISLIN_DIR}" \
    "${SCRIPT_DIR}/type0_rate_dislin.c" \
    -L"${DISLIN_DIR}" \
    -Wl,-rpath,"${DISLIN_DIR}" \
    -ldislin -lm \
    -o "${BIN}"

: > "${LOG}"
"${BIN}" "${INTERVAL_CSV}" "${SUMMARY_CSV}" "${CASE_NAME}" "${PNG}" | tee -a "${LOG}"
"${BIN}" "${INTERVAL_CSV}" "${SUMMARY_CSV}" "${CASE_NAME}" "${PDF}" | tee -a "${LOG}"

printf 'TYPE0_RATE_DISLIN_PASS case=%s png=%s pdf=%s log=%s\n' \
    "${CASE_NAME}" \
    "${PNG}" \
    "${PDF}" \
    "${LOG}"
