#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_DIR="$(realpath -m -- "${SCRIPT_DIR}/../..")"
REPORT_DIR="${SYSTEM_DIR}/tb_int/REPORT"
DISLIN_DIR="${DISLIN_DIR:-}"

DELAY_BINS_CSV="${1:?usage: render_type1_delay_dislin.sh <delay_bins.csv> <summary.csv> [source_name] [pattern_suffix] [output_prefix]}"
SUMMARY_CSV="${2:?usage: render_type1_delay_dislin.sh <delay_bins.csv> <summary.csv> [source_name] [pattern_suffix] [output_prefix]}"
SOURCE_NAME="${3:-type1_up}"
if [[ $# -ge 5 ]]; then
    PATTERN_SUFFIX="$4"
    OUT_PREFIX="$5"
elif [[ $# -ge 4 ]]; then
    PATTERN_SUFFIX="${PATTERN_SUFFIX:-onech}"
    OUT_PREFIX="$4"
else
    PATTERN_SUFFIX="${PATTERN_SUFFIX:-onech}"
    base="$(basename -- "${DELAY_BINS_CSV}")"
    OUT_PREFIX="${REPORT_DIR}/${base%_delay_bins.csv}_${SOURCE_NAME}_${PATTERN_SUFFIX}_delay_dislin"
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
BUILD_DIR="${REPORT_DIR}/dislin_work/type1_delay"
BIN="${BUILD_DIR}/type1_delay_dislin"
LOG="${OUT_PREFIX}.log"
PNG="${OUT_PREFIX}.png"
PDF="${OUT_PREFIX}.pdf"
META_CSV="${TYPE1_META_CSV:-${DELAY_BINS_CSV%_delay_bins.csv}_type1_meta.csv}"

mkdir -p "${BUILD_DIR}" "$(dirname -- "${OUT_PREFIX}")"

gcc -O2 -Wall -Wextra -std=c11 \
    -I"${DISLIN_DIR}" \
    "${SCRIPT_DIR}/type1_delay_dislin.c" \
    -L"${DISLIN_DIR}" \
    -Wl,-rpath,"${DISLIN_DIR}" \
    -ldislin -lm \
    -o "${BIN}"

: > "${LOG}"
if [[ -f "${META_CSV}" ]]; then
    "${BIN}" "${DELAY_BINS_CSV}" "${SUMMARY_CSV}" "${SOURCE_NAME}" "${PATTERN_SUFFIX}" "${PNG}" "${META_CSV}" | tee -a "${LOG}"
    "${BIN}" "${DELAY_BINS_CSV}" "${SUMMARY_CSV}" "${SOURCE_NAME}" "${PATTERN_SUFFIX}" "${PDF}" "${META_CSV}" | tee -a "${LOG}"
else
    "${BIN}" "${DELAY_BINS_CSV}" "${SUMMARY_CSV}" "${SOURCE_NAME}" "${PATTERN_SUFFIX}" "${PNG}" | tee -a "${LOG}"
    "${BIN}" "${DELAY_BINS_CSV}" "${SUMMARY_CSV}" "${SOURCE_NAME}" "${PATTERN_SUFFIX}" "${PDF}" | tee -a "${LOG}"
fi

printf 'TYPE1_DELAY_DISLIN_PASS source=%s pattern=%s png=%s pdf=%s log=%s\n' \
    "${SOURCE_NAME}" \
    "${PATTERN_SUFFIX}" \
    "${PNG}" \
    "${PDF}" \
    "${LOG}"
