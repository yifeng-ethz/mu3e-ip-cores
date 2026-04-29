#!/usr/bin/env bash
# Assemble raw single-run histogram dumps into the three wide CSVs consumed by
# render_phase5_histogram_sanity_dislin.sh. No Python is used.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RAW_DIR="${RAW_DIR:-${SYSTEM_DIR}/reports/phase5_histogram_raw_20260429}"
OUTPUT_DIR="${OUTPUT_DIR:-${SYSTEM_DIR}/reports/phase5_histogram_sanity_data_20260429}"

usage() {
  printf 'Usage: %s [--raw-dir DIR] [--output-dir DIR]\n' "$0"
  printf '\nExpected raw CSV names under --raw-dir:\n'
  printf '  rate_10k.csv rate_100k.csv\n'
  printf '  header_1.csv header_2.csv header_5.csv\n'
  printf '  delay_lane0.csv ... delay_lane7.csv\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --raw-dir)
      RAW_DIR="$2"
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

require_file() {
  if [[ ! -f "$1" ]]; then
    printf 'Missing raw CSV: %s\n' "$1" >&2
    exit 1
  fi
}

mkdir -p "${OUTPUT_DIR}"

require_file "${RAW_DIR}/rate_10k.csv"
require_file "${RAW_DIR}/rate_100k.csv"
{
  printf 'channel,10 kHz,100 kHz\n'
  paste -d, \
    <(awk -F, 'NR > 1 {printf "%d\n", $1}' "${RAW_DIR}/rate_10k.csv") \
    <(awk -F, 'NR > 1 {printf "%u\n", $3}' "${RAW_DIR}/rate_10k.csv") \
    <(awk -F, 'NR > 1 {printf "%u\n", $3}' "${RAW_DIR}/rate_100k.csv")
} > "${OUTPUT_DIR}/phase5_rate_10k_100k_256ch.csv"

for n in 1 2 5; do
  require_file "${RAW_DIR}/header_${n}.csv"
done
{
  printf 'delay_cycles,1/header,2/header,5/header\n'
  paste -d, \
    <(awk -F, 'NR > 1 {printf "%.3f\n", $2}' "${RAW_DIR}/header_1.csv") \
    <(awk -F, 'NR > 1 {printf "%u\n", $3}' "${RAW_DIR}/header_1.csv") \
    <(awk -F, 'NR > 1 {printf "%u\n", $3}' "${RAW_DIR}/header_2.csv") \
    <(awk -F, 'NR > 1 {printf "%u\n", $3}' "${RAW_DIR}/header_5.csv")
} > "${OUTPUT_DIR}/phase5_header_1_2_5.csv"

for lane in 0 1 2 3 4 5 6 7; do
  require_file "${RAW_DIR}/delay_lane${lane}.csv"
done
{
  printf 'delay_cycles,lane0,lane1,lane2,lane3,lane4,lane5,lane6,lane7\n'
  paste -d, \
    <(awk -F, 'NR > 1 {printf "%.3f\n", $2}' "${RAW_DIR}/delay_lane0.csv") \
    <(awk -F, 'NR > 1 {printf "%u\n", $3}' "${RAW_DIR}/delay_lane0.csv") \
    <(awk -F, 'NR > 1 {printf "%u\n", $3}' "${RAW_DIR}/delay_lane1.csv") \
    <(awk -F, 'NR > 1 {printf "%u\n", $3}' "${RAW_DIR}/delay_lane2.csv") \
    <(awk -F, 'NR > 1 {printf "%u\n", $3}' "${RAW_DIR}/delay_lane3.csv") \
    <(awk -F, 'NR > 1 {printf "%u\n", $3}' "${RAW_DIR}/delay_lane4.csv") \
    <(awk -F, 'NR > 1 {printf "%u\n", $3}' "${RAW_DIR}/delay_lane5.csv") \
    <(awk -F, 'NR > 1 {printf "%u\n", $3}' "${RAW_DIR}/delay_lane6.csv") \
    <(awk -F, 'NR > 1 {printf "%u\n", $3}' "${RAW_DIR}/delay_lane7.csv")
} > "${OUTPUT_DIR}/phase5_delay_lanes.csv"

printf 'Wrote %s\n' "${OUTPUT_DIR}/phase5_rate_10k_100k_256ch.csv"
printf 'Wrote %s\n' "${OUTPUT_DIR}/phase5_header_1_2_5.csv"
printf 'Wrote %s\n' "${OUTPUT_DIR}/phase5_delay_lanes.csv"
