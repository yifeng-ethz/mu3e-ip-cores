#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PHASE4_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd -- "${PHASE4_DIR}/../../../../.." && pwd)"
ARTIFACT_DIR="${ARTIFACT_DIR:-${PHASE4_DIR}/artifacts}"
WORK_DIR="${PHASE4_DIR}/work/tlm"

source "${REPO_ROOT}/scripts/questa_one_env.sh"

mkdir -p "${ARTIFACT_DIR}" "${WORK_DIR}"
cd "${WORK_DIR}"
rm -rf work transcript vsim.wlf
"${VLIB}" work
"${VMAP}" work work >/dev/null
"${VLOG}" -sv "${PHASE4_DIR}/tlm/phase4_latency_tlm.sv"
"${VSIM}" -c phase4_latency_tlm \
  -do "run -all; quit -f" \
  "+ARTIFACT_DIR=${ARTIFACT_DIR}" \
  | tee "${ARTIFACT_DIR}/phase4_tlm_run.log"
