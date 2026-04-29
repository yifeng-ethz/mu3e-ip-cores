#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
REPORT_DIR="${INT_ROOT}/REPORT/dp_injector_authentic"

mkdir -p "${REPORT_DIR}"

append_lane_args() {
  local args="$1"
  local lane
  for lane in 0 1 2 3 4 5 6 7; do
    args+=" +TB_DP_HIT_MODE_LANE${lane}=0"
    args+=" +TB_DP_BURST_SIZE_LANE${lane}=1"
    args+=" +TB_DP_BURST_CENTER_LANE${lane}=16"
  done
  printf '%s' "${args}"
}

run_cycles="${TB_DP_AUTH_RUN_CYCLES:-250000}"
inject_period="${TB_DP_AUTH_INJECT_PERIOD:-12500}"
inject_high="${TB_DP_AUTH_INJECT_HIGH:-5}"

vsim_args="+TB_DP_PRE_RBCAM_MEAS"
vsim_args+=" +TB_DP_USE_PERIODIC_INJECTOR"
vsim_args+=" +TB_DP_INJECT_MODE=2"
vsim_args+=" +TB_DP_INJECT_PERIOD=${inject_period}"
vsim_args+=" +TB_DP_INJECT_HIGH=${inject_high}"
vsim_args+=" +TB_DP_RUN_CYCLES=${run_cycles}"
vsim_args+=" +TB_DP_REPORT_DIR=${REPORT_DIR}"
vsim_args+=" +TB_DP_SHORT_MODE=1"
vsim_args+=" +TB_DP_HIT_RATE=0"
vsim_args+=" +TB_DP_NOISE_RATE=0"
vsim_args+=" +TB_DP_NO_FORCE_DECODED_DIN"
vsim_args+=" +TB_DP_USE_GENERATED_RUNCTL_FANOUT"
vsim_args="$(append_lane_args "${vsim_args}")"

export TB_DP_VSIM_ARGS="${vsim_args}"

echo "AUTHENTIC_DP_INJECTOR_REPORT_DIR : ${REPORT_DIR}"
echo "AUTHENTIC_DP_INJECTOR_RUN_CYCLES : ${run_cycles}"
echo "AUTHENTIC_DP_INJECTOR_PERIOD     : ${inject_period}"
echo "AUTHENTIC_DP_INJECTOR_HIGH       : ${inject_high}"
echo "AUTHENTIC_DP_INJECTOR_VSIM_ARGS  : ${TB_DP_VSIM_ARGS}"

"${SCRIPT_DIR}/run_dp_e2e.sh"
cp "${INT_ROOT}/REPORT/dp/run_dp_e2e.log" "${REPORT_DIR}/run_dp_injector_authentic.log"
