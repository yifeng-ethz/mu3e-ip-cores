#!/usr/bin/env bash
# Render Phase-6 ASIC/channel mask-response rate histograms with DISLIN bars.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${SYSTEM_DIR}/../../.." && pwd)"
REPORT_DIR="${REPORT_DIR:-${SYSTEM_DIR}/reports}"
OUTPUT_DIR="${OUTPUT_DIR:-${REPORT_DIR}/assets/phase6_mask_response_seed20260501}"
BUILD_DIR="${BUILD_DIR:-${OUTPUT_DIR}/.build_dislin}"
DISLIN_DIR="${DISLIN_DIR:-${REPO_ROOT}/packet_scheduler/.vendor/dislin}"
ASIC_SUMMARY="${ASIC_SUMMARY:-${REPORT_DIR}/phase6_mask_response_asic_lvds_seed20260501.summary.tsv}"
CHANNEL_SUMMARY="${CHANNEL_SUMMARY:-${REPORT_DIR}/phase6_mask_response_channel_seed20260501.summary.tsv}"
STATS_TSV="${STATS_TSV:-${OUTPUT_DIR}/phase6_mask_response_bar_stats.tsv}"

usage() {
  printf 'Usage: %s [--report-dir DIR] [--output-dir DIR]\n' "$0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report-dir)
      REPORT_DIR="$2"
      ASIC_SUMMARY="${REPORT_DIR}/phase6_mask_response_asic_lvds_seed20260501.summary.tsv"
      CHANNEL_SUMMARY="${REPORT_DIR}/phase6_mask_response_channel_seed20260501.summary.tsv"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      BUILD_DIR="${OUTPUT_DIR}/.build_dislin"
      STATS_TSV="${OUTPUT_DIR}/phase6_mask_response_bar_stats.tsv"
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

gcc -O2 -Wall -Wextra -std=c11 \
  -I"${DISLIN_DIR}" \
  "${SCRIPT_DIR}/render_phase6_mask_rate_bar_dislin.c" \
  -L"${DISLIN_DIR}" \
  -Wl,-rpath,"${DISLIN_DIR}" \
  -ldislin -lm \
  -o "${BUILD_DIR}/render_phase6_mask_rate_bar_dislin"

printf 'kind\tcase\ttotal_hz\tmean_hz_per_channel\tnonzero_channels\tmin_hz_per_channel\tmax_hz_per_channel\tspan_hz_per_channel\tcv_all_channels\tplot\n' > "${STATS_TSV}"

while IFS=$'\t' read -r case seed kind lvds_mask lanes expected_channels csv json md returncode; do
  [[ "${case}" == "case" ]] && continue
  out="${OUTPUT_DIR}/phase6_mask_response_${kind}_case${case}_ph05_bar.png"
  title="Phase-6 ASIC LVDS mask case ${case}: mask=${lvds_mask}, lanes=${lanes}"
  subtitle="pulse_high=5; 1 s rate preset; expected active channels=${expected_channels}; seed=${seed}"
  tmp_log="${BUILD_DIR}/render_${kind}_case${case}.log"
  "${BUILD_DIR}/render_phase6_mask_rate_bar_dislin" "${csv}" "${out}" "${title}" "${subtitle}" > "${tmp_log}" 2>&1
  row="$(awk -F '\t' '/^[0-9]+(\.[0-9]+)?\t/ { print; exit }' "${tmp_log}")"
  printf '%s\t%s\t%s\n' "${kind}" "${case}" "${row}" >> "${STATS_TSV}"
done < "${ASIC_SUMMARY}"

while IFS=$'\t' read -r case seed kind channel_mask enabled masked csv json md config_json returncode; do
  [[ "${case}" == "case" ]] && continue
  out="${OUTPUT_DIR}/phase6_mask_response_${kind}_case${case}_ph05_bar.png"
  title="Phase-6 channel mask case ${case}: mask=${channel_mask}"
  subtitle="pulse_high=5; 1 s rate preset; enabled=${enabled}/32 per ASIC, masked=${masked}/32; seed=${seed}"
  tmp_log="${BUILD_DIR}/render_${kind}_case${case}.log"
  "${BUILD_DIR}/render_phase6_mask_rate_bar_dislin" "${csv}" "${out}" "${title}" "${subtitle}" > "${tmp_log}" 2>&1
  row="$(awk -F '\t' '/^[0-9]+(\.[0-9]+)?\t/ { print; exit }' "${tmp_log}")"
  printf '%s\t%s\t%s\n' "${kind}" "${case}" "${row}" >> "${STATS_TSV}"
done < "${CHANNEL_SUMMARY}"

montage "${OUTPUT_DIR}"/phase6_mask_response_asic_lvds_case*_ph05_bar.png \
  -thumbnail 760x472 -tile 2x4 -geometry +18+24 -background white \
  -border 2 -bordercolor '#d0d0d0' \
  "${OUTPUT_DIR}/phase6_mask_response_asic_lvds_contact_sheet.png"

montage "${OUTPUT_DIR}"/phase6_mask_response_channel_mask_case*_ph05_bar.png \
  -thumbnail 760x472 -tile 2x4 -geometry +18+24 -background white \
  -border 2 -bordercolor '#d0d0d0' \
  "${OUTPUT_DIR}/phase6_mask_response_channel_mask_contact_sheet.png"

printf 'Mask-response bar plots written under %s\n' "${OUTPUT_DIR}"
printf 'Summary: %s\n' "${STATS_TSV}"
