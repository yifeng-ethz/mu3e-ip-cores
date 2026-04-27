#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

INT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
SWEEP_DIR="${INT_ROOT}/REPORT/dp_rate_sweep"
RATE_CASES=(
  "10k 10000 12500 1250000"
  "100k 100000 1250 625000"
  "500k 500000 250 250000"
)

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

mkdir -p "${SWEEP_DIR}"

echo "Running datapath histogram sweep with per-rate calibrated run windows"

for case_entry in "${RATE_CASES[@]}"; do
  read -r tag rate_hz inject_period run_cycles <<<"${case_entry}"
  rate_dir="${SWEEP_DIR}/${tag}"
  mkdir -p "${rate_dir}"
  duration_s="$(python3 - <<PY
run_cycles = int("${run_cycles}")
print(f"{run_cycles / 125000000.0:.9f}")
PY
)"

  vsim_args="+TB_DP_PRE_RBCAM_MEAS"
  vsim_args+=" +TB_DP_USE_PERIODIC_INJECTOR"
  vsim_args+=" +TB_DP_INJECT_MODE=2"
  vsim_args+=" +TB_DP_INJECT_PERIOD=${inject_period}"
  vsim_args+=" +TB_DP_INJECT_HIGH=5"
  vsim_args+=" +TB_DP_RUN_CYCLES=${run_cycles}"
  vsim_args+=" +TB_DP_REPORT_DIR=${rate_dir}"
  vsim_args+=" +TB_DP_SHORT_MODE=1"
  vsim_args+=" +TB_DP_HIT_RATE=0"
  vsim_args+=" +TB_DP_NOISE_RATE=0"
  vsim_args="$(append_lane_args "${vsim_args}")"

  echo "=== ${tag}: ${rate_hz} Hz/ch, injector period ${inject_period} cycles, run_cycles ${run_cycles} (${duration_s}s) ==="
  export TB_DP_VSIM_ARGS="${vsim_args}"
  "${SCRIPT_DIR}/run_dp_e2e.sh"
  cp "${INT_ROOT}/REPORT/dp/run_dp_e2e.log" "${rate_dir}/run.log"
  python3 "${SCRIPT_DIR}/analyze_pre_rbcam_hist.py" --report-dir "${rate_dir}" --json-out "${rate_dir}/summary.json"
  python3 "${SCRIPT_DIR}/check_dp_hist_rate.py" \
    --report-dir "${rate_dir}" \
    --expected-rate-hz "${rate_hz}" \
    --duration-s "${duration_s}" \
    | tee "${rate_dir}/rate_check.txt"
done

echo "Sweep complete. Reports in ${SWEEP_DIR}"
