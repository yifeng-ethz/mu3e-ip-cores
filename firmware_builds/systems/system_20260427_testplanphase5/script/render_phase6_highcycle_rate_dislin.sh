#!/usr/bin/env bash
# Render real-MuTRiG high-cycle rate sweep figures with DISLIN.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${SYSTEM_DIR}/../../.." && pwd)"
REPORT_DIR="${REPORT_DIR:-${SYSTEM_DIR}/reports}"
OUTPUT_DIR="${OUTPUT_DIR:-${REPORT_DIR}/assets/phase6_highcycle_rate_sweep_20260501}"
BUILD_DIR="${BUILD_DIR:-${OUTPUT_DIR}/.build_dislin}"
DISLIN_DIR="${DISLIN_DIR:-${REPO_ROOT}/packet_scheduler/.vendor/dislin}"
INPUT_PATTERN="${INPUT_PATTERN:-${REPORT_DIR}/phase6_rate_per_channel_1s_real_full32_cml080_ph%02d_20260501.csv}"
SUMMARY_TSV="${SUMMARY_TSV:-${OUTPUT_DIR}/phase6_highcycle_rate_sweep_stats.tsv}"
RENDER_LOG="${RENDER_LOG:-${OUTPUT_DIR}/render_phase6_highcycle_rate_dislin.log}"

usage() {
  printf 'Usage: %s [--report-dir DIR] [--output-dir DIR] [--input-pattern PATTERN]\n' "$0"
  printf '\nPATTERN must be a printf pattern with one integer field for pulse_high, e.g. ph%%02d.csv.\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report-dir)
      REPORT_DIR="$2"
      INPUT_PATTERN="${REPORT_DIR}/phase6_rate_per_channel_1s_real_full32_cml080_ph%02d_20260501.csv"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      BUILD_DIR="${OUTPUT_DIR}/.build_dislin"
      SUMMARY_TSV="${OUTPUT_DIR}/phase6_highcycle_rate_sweep_stats.tsv"
      shift 2
      ;;
    --input-pattern)
      INPUT_PATTERN="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

mkdir -p "${OUTPUT_DIR}" "${BUILD_DIR}"

if [[ ! -d "${DISLIN_DIR}" ]]; then
  printf 'DISLIN_DIR does not exist: %s\n' "${DISLIN_DIR}" >&2
  exit 1
fi

gcc -O2 -Wall -Wextra -std=c11 \
  -I"${DISLIN_DIR}" \
  "${SCRIPT_DIR}/render_phase6_highcycle_rate_dislin.c" \
  -L"${DISLIN_DIR}" \
  -Wl,-rpath,"${DISLIN_DIR}" \
  -ldislin -lm \
  -o "${BUILD_DIR}/render_phase6_highcycle_rate_dislin"

printf 'pulse_high\ttotal_hz\tmean_hz_per_channel\tnonzero_channels\tmin_hz_per_channel\tmax_hz_per_channel\tspan_hz_per_channel\tcv_all_channels\tplot\n' > "${SUMMARY_TSV}"
: > "${RENDER_LOG}"

for pulse_high in $(seq 1 15); do
  input_path="$(printf "${INPUT_PATTERN}" "${pulse_high}")"
  output_path="${OUTPUT_DIR}/phase6_rate_per_channel_1s_ph$(printf '%02d' "${pulse_high}")_dislin.png"
  tmp_log="${BUILD_DIR}/render_ph$(printf '%02d' "${pulse_high}").log"
  if [[ ! -f "${input_path}" ]]; then
    printf 'missing input for pulse_high=%s: %s\n' "${pulse_high}" "${input_path}" >&2
    exit 1
  fi
  "${BUILD_DIR}/render_phase6_highcycle_rate_dislin" \
    "${input_path}" \
    "${output_path}" \
    "${pulse_high}" \
    "1 s rate preset; CML 0-8-0; 8 ASICs x 32 TDC-test channels; interval=1250 cycles" \
    > "${tmp_log}" 2>&1
  cat "${tmp_log}" >> "${RENDER_LOG}"
  awk -F '\t' '/^[0-9]+\t/ { print }' "${tmp_log}" >> "${SUMMARY_TSV}"
  printf 'Wrote %s\n' "${output_path}"
done

printf 'DISLIN high-cycle rate sweep plots written under %s\n' "${OUTPUT_DIR}"
printf 'Summary: %s\n' "${SUMMARY_TSV}"
