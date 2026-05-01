#!/usr/bin/env bash
# Capture one real-MuTRiG header-sync delay histogram per ASIC.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPORT_DIR="${REPORT_DIR:-${SYSTEM_DIR}/reports}"
DATE_TAG="${DATE_TAG:-20260501}"
SUMMARY_TSV="${SUMMARY_TSV:-${REPORT_DIR}/phase6_header_delay_asic_hsync_ph05_hitdelay_${DATE_TAG}.summary.tsv}"
ASICS="${ASICS:-0 1 2 3 4 5 6 7}"

mkdir -p "${REPORT_DIR}"
printf 'asic\tlane_mask\thist_source\tcsv\tjson\tlog\treturncode\n' > "${SUMMARY_TSV}"

for asic in ${ASICS}; do
  lane_mask=$((1 << asic))
  lane_mask_hex="$(printf '0x%02X' "${lane_mask}")"
  hist_source="normal_hit_t"
  prefix="${REPORT_DIR}/phase6_header_delay_asic${asic}_hsync_ph05_hitdelay_${DATE_TAG}"
  csv="${prefix}.csv"
  json="${prefix}.json"
  md="${prefix}.md"
  log="${prefix}.log"
  set +e
  python3 "${SCRIPT_DIR}/run_phase5_injector_datapath_sanity.py" \
    --source real \
    --lvds-lane-mask "${lane_mask_hex}" \
    --inject-mode header \
    --hist-profile delay-hit-t \
    --hist-ingress-source pre \
    --hist-filter-enable \
    --hist-filter-key-value "${asic}" \
    --pulse-intervals 12500 \
    --pulse-high-cycles 5 \
    --header-delay 100 \
    --header-interval 1 \
    --header-channel "${asic}" \
    --injection-multiplicity 1 \
    --duration-ms 1500 \
    --mts-expected-latency 2000 \
    --mts-delay-ts-field t \
    --mts-drop-delay-error off \
    --mts-discard-tolerance-pct 1.0 \
    --ring-filter-inerr on \
    --capture-lvds \
    --read-lvds-dpa-unlocks \
    --jtag-hist-csv "${csv}" \
    --jtag-hist-log "${log}" \
    --jtag-hist-profile delay-hit-t \
    --jtag-hist-lane-filter "${asic}" \
    --jtag-hist-timeout-s 90 \
    --output "${md}" \
    --json-output "${json}"
  rc=$?
  set -e
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "${asic}" "${lane_mask_hex}" "${hist_source}" "${csv}" "${json}" "${log}" "${rc}" >> "${SUMMARY_TSV}"
done

printf 'Summary: %s\n' "${SUMMARY_TSV}"
