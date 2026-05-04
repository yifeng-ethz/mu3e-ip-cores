#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

setup_questa_license

DOMAIN="dp_source_mux_direct"
prepare_domain_tree "${DOMAIN}"

BUILD_DIR="$(work_dir "${DOMAIN}")"
REPORT_DIR="$(report_dir "${DOMAIN}")"
WORK_LIB="${BUILD_DIR}/work_source_mux_direct"
LOG_FILE="${REPORT_DIR}/run_source_mux_direct.log"

mkdir -p "${BUILD_DIR}" "${REPORT_DIR}"

echo "═══ Compiling mutrig_lane_source_mux direct timing-control test ═══"
cd "${BUILD_DIR}"
rm -f transcript vsim.wlf
create_work_lib "${WORK_LIB}"
map_intel_libs "${WORK_LIB}"

run_vlog -work "${WORK_LIB}" -sv "${REPO_ROOT}/misc/mutrig_lane_source_mux/rtl/mutrig_lane_source_mux.sv"
run_vlog -work "${WORK_LIB}" -sv "${STATIC_TB_DIR}/tb_mutrig_lane_source_mux_direct.sv"

echo "═══ Running mutrig_lane_source_mux direct timing-control test ═══"
run_vsim_logged "${LOG_FILE}" \
  "${VSIM}" -c -do "run -all; quit -f" \
  -work "${WORK_LIB}" -t ps -voptargs=+acc \
  tb_mutrig_lane_source_mux_direct
