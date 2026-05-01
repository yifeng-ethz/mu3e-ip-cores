#!/usr/bin/env bash
# Render Phase-6 per-ASIC header-sync delay histograms with DISLIN bars.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${SYSTEM_DIR}/../../.." && pwd)"
REPORT_DIR="${REPORT_DIR:-${SYSTEM_DIR}/reports}"
OUTPUT_DIR="${OUTPUT_DIR:-${REPORT_DIR}/assets/phase6_header_delay_asic_hitdelay_20260501}"
BUILD_DIR="${BUILD_DIR:-${OUTPUT_DIR}/.build_dislin}"
DISLIN_DIR="${DISLIN_DIR:-${REPO_ROOT}/packet_scheduler/.vendor/dislin}"
INPUT_SUMMARY="${INPUT_SUMMARY:-${REPORT_DIR}/phase6_header_delay_asic_hsync_ph05_hitdelay_20260501.summary.tsv}"
STATS_TSV="${STATS_TSV:-${OUTPUT_DIR}/phase6_header_delay_asic_stats.tsv}"

usage() {
  printf 'Usage: %s [--report-dir DIR] [--output-dir DIR] [--input-summary FILE]\n' "$0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report-dir)
      REPORT_DIR="$2"
      INPUT_SUMMARY="${REPORT_DIR}/phase6_header_delay_asic_hsync_ph05_hitdelay_20260501.summary.tsv"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      BUILD_DIR="${OUTPUT_DIR}/.build_dislin"
      STATS_TSV="${OUTPUT_DIR}/phase6_header_delay_asic_stats.tsv"
      shift 2
      ;;
    --input-summary)
      INPUT_SUMMARY="$2"
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

if [[ ! -f "${INPUT_SUMMARY}" ]]; then
  printf 'missing input summary: %s\n' "${INPUT_SUMMARY}" >&2
  exit 1
fi
if [[ ! -d "${DISLIN_DIR}" ]]; then
  printf 'DISLIN_DIR does not exist: %s\n' "${DISLIN_DIR}" >&2
  exit 1
fi

gcc -O2 -Wall -Wextra -std=c11 \
  -I"${DISLIN_DIR}" \
  "${SCRIPT_DIR}/render_phase6_header_delay_dislin.c" \
  -L"${DISLIN_DIR}" \
  -Wl,-rpath,"${DISLIN_DIR}" \
  -ldislin -lm \
  -o "${BUILD_DIR}/render_phase6_header_delay_dislin"

printf 'asic\tlane_mask\thist_source\treturncode\ttotal_hits\tnonzero_bins\tpeak_bin\tpeak_center_cycles\tpeak_fraction\tinband_0_2000_hits\toutband_lt0_hits\toutband_gt2000_hits\tinband_0_2000_fraction\toutband_fraction\trbcam_drop_proxy_fraction\thist_underflow_wait_delta\thist_overflow_wait_delta\thist_underflow_read_delta\thist_overflow_read_delta\trbcam_drop_proxy_with_counter_fraction\tplot\tcsv\tjson\tlog\n' > "${STATS_TSV}"

while IFS=$'\t' read -r asic lane_mask hist_source csv json log returncode; do
  [[ "${asic}" == "asic" ]] && continue
  if [[ ! -f "${csv}" ]]; then
    printf '%s\t%s\t%s\t%s\t0\t0\t0\t0.000\t0.000000000\t0\t0\t0\t0.000000000\t0.000000000\t0.000000000\t0\t0\t0\t0\t0.000000000\t\t%s\t%s\t%s\n' \
      "${asic}" "${lane_mask}" "${hist_source}" "${returncode}" "${csv}" "${json}" "${log}" >> "${STATS_TSV}"
    continue
  fi
  out="${OUTPUT_DIR}/phase6_header_delay_asic${asic}_hsync_ph05_dislin.png"
  title="Phase-6 Header-Sync Delay: ASIC ${asic}"
  subtitle="real MuTRiG; pulse_high=5; lane_mask=${lane_mask}; hist source=${hist_source}; range [-1000, 3096]"
  tmp_log="${BUILD_DIR}/render_asic${asic}.log"
  "${BUILD_DIR}/render_phase6_header_delay_dislin" "${csv}" "${out}" "${title}" "${subtitle}" > "${tmp_log}" 2>&1
  row="$(awk -F '\t' '/^[0-9]+\t/ { print; exit }' "${tmp_log}")"
  IFS=$'\t' read -r total_hits nonzero_bins peak_bin peak_center peak_fraction inband_hits outband_lt0_hits outband_gt2000_hits inband_fraction outband_fraction rbcam_drop_proxy_fraction plot_path <<< "${row}"
  uf_before="$(sed -nE 's/.*stats_before_wait=\{underflow_count ([0-9]+).*/\1/p' "${log}" | tail -1 || true)"
  uf_after="$(sed -nE 's/.*stats_after_wait=\{underflow_count ([0-9]+).*/\1/p' "${log}" | tail -1 || true)"
  of_before="$(sed -nE 's/.*stats_before_wait=\{underflow_count [0-9]+ overflow_count ([0-9]+).*/\1/p' "${log}" | tail -1 || true)"
  of_after="$(sed -nE 's/.*stats_after_wait=\{underflow_count [0-9]+ overflow_count ([0-9]+).*/\1/p' "${log}" | tail -1 || true)"
  uf_read="$(sed -nE 's/.*underflow_delta_read=([0-9]+).*/\1/p' "${log}" | tail -1 || true)"
  of_read="$(sed -nE 's/.*overflow_delta_read=([0-9]+).*/\1/p' "${log}" | tail -1 || true)"
  uf_wait=$(( ${uf_after:-0} - ${uf_before:-0} ))
  of_wait=$(( ${of_after:-0} - ${of_before:-0} ))
  proxy_with_counters="$(awk \
    -v total="${total_hits:-0}" \
    -v below="${outband_lt0_hits:-0}" \
    -v above="${outband_gt2000_hits:-0}" \
    -v uf="${uf_wait:-0}" \
    -v of="${of_wait:-0}" \
    'BEGIN { den = total + uf + of; if (den > 0) printf "%.9f", (below + above + uf + of) / den; else printf "0.000000000"; }')"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "${asic}" "${lane_mask}" "${hist_source}" "${returncode}" \
    "${total_hits}" "${nonzero_bins}" "${peak_bin}" "${peak_center}" "${peak_fraction}" \
    "${inband_hits}" "${outband_lt0_hits}" "${outband_gt2000_hits}" \
    "${inband_fraction}" "${outband_fraction}" "${rbcam_drop_proxy_fraction}" \
    "${uf_wait}" "${of_wait}" "${uf_read:-0}" "${of_read:-0}" "${proxy_with_counters}" \
    "${plot_path}" "${csv}" "${json}" "${log}" >> "${STATS_TSV}"
  printf 'Wrote %s\n' "${out}"
done < "${INPUT_SUMMARY}"

if compgen -G "${OUTPUT_DIR}/phase6_header_delay_asic*_hsync_ph05_dislin.png" > /dev/null; then
  montage "${OUTPUT_DIR}"/phase6_header_delay_asic*_hsync_ph05_dislin.png \
    -thumbnail 760x472 -tile 2x4 -geometry +18+24 -background white \
    -border 2 -bordercolor '#d0d0d0' \
    "${OUTPUT_DIR}/phase6_header_delay_asic_contact_sheet.png"
fi

printf 'Header-sync delay plots written under %s\n' "${OUTPUT_DIR}"
printf 'Summary: %s\n' "${STATS_TSV}"
