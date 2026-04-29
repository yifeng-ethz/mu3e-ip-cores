#!/usr/bin/env bash
# Render Phase-5 histogram sanity figures with DISLIN only.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${SYSTEM_DIR}/../../.." && pwd)"
INPUT_DIR="${INPUT_DIR:-${SYSTEM_DIR}/reports/phase5_histogram_sanity_data_20260429}"
OUTPUT_DIR="${OUTPUT_DIR:-${SYSTEM_DIR}/reports/phase5_histogram_sanity_20260429}"
BUILD_DIR="${BUILD_DIR:-${OUTPUT_DIR}/.build_dislin}"
DISLIN_DIR="${DISLIN_DIR:-${REPO_ROOT}/packet_scheduler/.vendor/dislin}"

usage() {
  printf 'Usage: %s [--input-dir DIR] [--output-dir DIR]\n' "$0"
  printf '\nRequired input CSV files:\n'
  printf '  phase5_rate_10k_100k_256ch.csv    columns: channel,10k,100k\n'
  printf '  phase5_header_1_2_5.csv            columns: delay_cycles,1_per_header,2_per_header,5_per_header\n'
  printf '  phase5_delay_lanes.csv             columns: delay_cycles,lane0,...,lane7\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input-dir)
      INPUT_DIR="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
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
  "${SCRIPT_DIR}/render_phase5_histogram_sanity_dislin.c" \
  -L"${DISLIN_DIR}" \
  -Wl,-rpath,"${DISLIN_DIR}" \
  -ldislin -lm \
  -o "${BUILD_DIR}/render_phase5_histogram_sanity_dislin"

render_one() {
  local mode="$1"
  local input_name="$2"
  local output_name="$3"
  local input_path="${INPUT_DIR}/${input_name}"
  local output_path="${OUTPUT_DIR}/${output_name}"

  if [[ ! -f "${input_path}" ]]; then
    printf 'Missing input CSV for %s: %s\n' "${mode}" "${input_path}" >&2
    exit 1
  fi

  "${BUILD_DIR}/render_phase5_histogram_sanity_dislin" "${mode}" "${input_path}" "${output_path}" \
    | tee -a "${OUTPUT_DIR}/render_phase5_histogram_sanity_dislin.log"
  printf 'Wrote %s\n' "${output_path}"
}

: > "${OUTPUT_DIR}/render_phase5_histogram_sanity_dislin.log"

render_one rate phase5_rate_10k_100k_256ch.csv phase5_rate_10k_100k_256ch.png
render_one header phase5_header_1_2_5.csv phase5_header_1_2_5.png
render_one delay phase5_delay_lanes.csv phase5_delay_lanes.png

printf 'DISLIN Phase-5 histogram sanity plots written under %s\n' "${OUTPUT_DIR}"
