#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PHASE4_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd -- "${PHASE4_DIR}/../../.." && pwd)"
ARTIFACT_DIR="${ARTIFACT_DIR:-${PHASE4_DIR}/artifacts}"
BUILD_DIR="${PHASE4_DIR}/work/plot"
DISLIN_DIR="${DISLIN_DIR:-${REPO_ROOT}/packet_scheduler/.vendor/dislin}"

mkdir -p "${ARTIFACT_DIR}" "${BUILD_DIR}"

python3 "${SCRIPT_DIR}/collect_phase4_artifacts.py" \
  --repo-root "${REPO_ROOT}" \
  --artifact-dir "${ARTIFACT_DIR}"

gcc -O2 -Wall -Wextra -std=c11 \
  -I"${DISLIN_DIR}" \
  "${SCRIPT_DIR}/phase4_dislin_plots.c" \
  -L"${DISLIN_DIR}" \
  -Wl,-rpath,"${DISLIN_DIR}" \
  -ldislin -lm \
  -o "${BUILD_DIR}/phase4_dislin_plots"

"${BUILD_DIR}/phase4_dislin_plots" \
  "${ARTIFACT_DIR}/phase4_tlm_latency_hist.csv" \
  "${ARTIFACT_DIR}/phase4_rtl_latency_hist.csv" \
  "${ARTIFACT_DIR}/phase4_rate_sweep.csv" \
  "${ARTIFACT_DIR}/phase4_latency_tlm_vs_rtl.png" \
  "${ARTIFACT_DIR}/phase4_rate_sweep.png" \
  | tee "${ARTIFACT_DIR}/phase4_dislin_png.log"

"${BUILD_DIR}/phase4_dislin_plots" \
  "${ARTIFACT_DIR}/phase4_tlm_latency_hist.csv" \
  "${ARTIFACT_DIR}/phase4_rtl_latency_hist.csv" \
  "${ARTIFACT_DIR}/phase4_rate_sweep.csv" \
  "${ARTIFACT_DIR}/phase4_latency_tlm_vs_rtl.svg" \
  "${ARTIFACT_DIR}/phase4_rate_sweep.svg" \
  | tee "${ARTIFACT_DIR}/phase4_dislin_svg.log"

printf 'Wrote %s\n' "${ARTIFACT_DIR}/phase4_latency_tlm_vs_rtl.png"
printf 'Wrote %s\n' "${ARTIFACT_DIR}/phase4_rate_sweep.png"
