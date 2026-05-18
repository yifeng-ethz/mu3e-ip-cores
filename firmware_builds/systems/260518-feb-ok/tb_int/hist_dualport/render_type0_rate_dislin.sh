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
RUN_ID="${BASHPID:-$$}"
BIN="${BUILD_DIR}/type0_rate_dislin_${RUN_ID}"
LOG="${OUT_PREFIX}.log"
PNG="${OUT_PREFIX}.png"
PDF="${OUT_PREFIX}.pdf"
TMP_PARENT="${BUILD_DIR}/tmp"

mkdir -p "${BUILD_DIR}" "${TMP_PARENT}" "$(dirname -- "${OUT_PREFIX}")"
TMP_DIR="$(mktemp -d "${TMP_PARENT}/mu3e_type0_rate.XXXXXX")"
TEMP_PREFIX="${TMP_DIR}/plot"

gcc -O2 -Wall -Wextra -std=c11 \
    -I"${DISLIN_DIR}" \
    "${SCRIPT_DIR}/type0_rate_dislin.c" \
    -L"${DISLIN_DIR}" \
    -Wl,-rpath,"${DISLIN_DIR}" \
    -ldislin -lm \
    -o "${BIN}"

: > "${LOG}"

render_one() {
    local final_path="$1"
    local temp_path="$2"
    if [[ -e "${temp_path}" || -e "${final_path}" ]]; then
        echo "refusing to overwrite DISLIN output: ${temp_path} or ${final_path}" >&2
        return 1
    fi
    "${BIN}" "${INTERVAL_CSV}" "${SUMMARY_CSV}" "${CASE_NAME}" "${temp_path}" | tee -a "${LOG}"
    if [[ ! -s "${temp_path}" ]]; then
        echo "DISLIN did not create ${temp_path}" >&2
        return 1
    fi
    cp "${temp_path}" "${final_path}"
    if [[ ! -s "${final_path}" ]]; then
        echo "failed to copy DISLIN output to ${final_path}" >&2
        return 1
    fi
}

render_one "${PNG}" "${TEMP_PREFIX}.png"
render_one "${PDF}" "${TEMP_PREFIX}.pdf"

printf 'TYPE0_RATE_DISLIN_PASS case=%s png=%s pdf=%s log=%s\n' \
    "${CASE_NAME}" \
    "${PNG}" \
    "${PDF}" \
    "${LOG}"
