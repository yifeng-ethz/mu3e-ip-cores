#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

setup_questa_license

DOMAIN="dp"
prepare_domain_tree "${DOMAIN}"

BUILD_DIR="$(work_dir "${DOMAIN}")"
GEN_DIR="$(generated_dir "${DOMAIN}")"
REPORT_DIR="$(report_dir "${DOMAIN}")"
SRC_DIR="${GEN_DIR}/src"
QUIET_RTL_DIR="${GEN_DIR}/quiet_rtl"
WORK_LIB="${BUILD_DIR}/work_dp_e2e"
LOG_FILE="${REPORT_DIR}/run_dp_e2e.log"
QUIET_DP_TOP="${QUIET_RTL_DIR}/${DP_TARGET_ENTITY}.vhd"
QUIET_DP_WRAPPER="${SRC_DIR}/scifi_dp_emu_live_wrapper_v3.vhd"
EXTRA_VSIM_ARGS=()

mkdir -p "${BUILD_DIR}" "${SRC_DIR}" "${QUIET_RTL_DIR}" "${REPORT_DIR}"
if [[ -n "${TB_DP_VSIM_ARGS:-}" ]]; then
  # Allow callers to pass plusargs like:
  #   TB_DP_VSIM_ARGS='+TB_DP_PRE_RBCAM_MEAS +TB_DP_RUN_CYCLES=100000 +TB_DP_SHORT_MODE=1 +TB_DP_REPORT_DIR=/abs/path'
  read -r -a EXTRA_VSIM_ARGS <<< "${TB_DP_VSIM_ARGS}"
fi
python3 "${SCRIPT_DIR}/prepare_quiet_timing_adapters.py" \
  --qip "${DP_QIP}" \
  --synth-dir "${DP_SYNTH}" \
  --out-dir "${QUIET_RTL_DIR}"
python3 "${SCRIPT_DIR}/prepare_quiet_dp_top.py" \
  --src "${DP_SYNTH}/${DP_TARGET_ENTITY}.vhd" \
  --out-dir "${QUIET_RTL_DIR}"
python3 "${SCRIPT_DIR}/prepare_dp_wrapper.py" \
  --src "${STATIC_TB_DIR}/scifi_dp_emu_live_wrapper_v3.vhd" \
  --target-entity "${DP_TARGET_ENTITY}" \
  --out-dir "${SRC_DIR}"

echo "═══ Compiling FE SciFi v3 datapath E2E harness ═══"
cd "${BUILD_DIR}"
rm -f transcript vsim.wlf
create_work_lib "${WORK_LIB}"
map_intel_libs "${WORK_LIB}"

run_vcom -work "${WORK_LIB}" -2008 "${STATIC_TB_DIR}/altera_lvds_rx_28nm.vhd"
compile_qip "${WORK_LIB}" "${DP_SYNTH}" "${DP_QIP}" "${DP_TARGET_ENTITY}" "(altera_lvds_rx_28nm\\.vhd|${DP_TARGET_ENTITY}\\.vhd|timing_adapter_[0-9]+\\.sv|timing_adt\\.sv)$"
while IFS= read -r f; do
  run_vlog -work "${WORK_LIB}" \
    -L altera_ver -L altera_mf_ver -L altera_lnsim_ver -L lpm_ver -L 220model_ver -L twentynm_ver -L sgate_ver \
    -sv "${f}"
done < <(find "${QUIET_RTL_DIR}" -maxdepth 1 -type f -name '*.sv' | sort)
run_vcom -work "${WORK_LIB}" -2008 "${STATIC_TB_DIR}/tb_int_histogram_wrap.vhd"
run_vcom -work "${WORK_LIB}" -2008 "${QUIET_DP_TOP}"
run_vcom -work "${WORK_LIB}" -2008 "${QUIET_DP_WRAPPER}"
run_vlog -work "${WORK_LIB}" -sv "${STATIC_TB_DIR}/tb_scifi_dp_v3_emu_smoke.sv"
symlink_init_files "${BUILD_DIR}" "${DP_SYNTH}"

read -r -d '' VSIM_DO <<'EOF' || true
quietly set NumericStdNoWarnings 1
quietly set StdArithNoWarnings 1
proc first_existing_path {paths} {
  foreach path $paths {
    if {![catch {examine $path}]} {
      return $path
    }
  }
  puts "ERROR: none of the candidate paths exist: $paths"
  quit -code 1 -f
}
set datapath_translator_reset_path [first_existing_path [list \
  /tb_scifi_dp_v3_emu_smoke/dut_wrap/dut/mm_interconnect_1/mm_pipeline_jtagmaster2rstctrl_reset_reset_bridge_in_reset_reset \
  /tb_scifi_dp_v3_emu_smoke/dut_wrap/dut/mm_interconnect_1/master_datapath_master_translator_reset_reset_bridge_in_reset_reset]]
set datapath_master_reset_path [first_existing_path [list \
  /tb_scifi_dp_v3_emu_smoke/dut_wrap/dut/master_datapath/master_reset_reset \
  /tb_scifi_dp_v3_emu_smoke/dut_wrap/dut/master_datapath_master_reset_reset]]
set datapath_master_clk_reset_path [first_existing_path [list \
  /tb_scifi_dp_v3_emu_smoke/dut_wrap/dut/mm_interconnect_1/master_datapath_clk_reset_reset_bridge_in_reset_reset \
  /tb_scifi_dp_v3_emu_smoke/dut_wrap/dut/mm_interconnect_0/master_datapath_clk_reset_reset_bridge_in_reset_reset]]
set datapath_lvds_reset_path [first_existing_path [list \
  /tb_scifi_dp_v3_emu_smoke/dut_wrap/dut/rst_controller_006_reset_out_reset \
  /tb_scifi_dp_v3_emu_smoke/dut_wrap/dut/mm_interconnect_0/mm_pipeline_lvds_csr_low_reset_reset_bridge_in_reset_reset \
  /tb_scifi_dp_v3_emu_smoke/dut_wrap/dut/mm_interconnect_1/mm_pipeline_lvds_csr_reset_reset_bridge_in_reset_reset \
  /tb_scifi_dp_v3_emu_smoke/dut_wrap/dut/mm_interconnect_0/mm_pipeline_lvds_csr_reset_reset_bridge_in_reset_reset \
  /tb_scifi_dp_v3_emu_smoke/dut_wrap/dut/mm_interconnect_1/mm_pipeline_avmm_lvds_reset_reset_bridge_in_reset_reset \
  /tb_scifi_dp_v3_emu_smoke/dut_wrap/dut/mm_interconnect_0/mm_pipeline_avmm_lvds_reset_reset_bridge_in_reset_reset]]
set datapath_mutrig_reset_path [first_existing_path [list \
  /tb_scifi_dp_v3_emu_smoke/dut_wrap/dut/mm_interconnect_1/mutrig_datapath_subsystem_0_reset_reset_bridge_in_reset_reset \
  /tb_scifi_dp_v3_emu_smoke/dut_wrap/dut/mm_interconnect_0/mutrig_datapath_subsystem_0_reset_reset_bridge_in_reset_reset]]
force -freeze $datapath_master_reset_path 0 0
force -freeze $datapath_master_clk_reset_path 1 0
force -freeze $datapath_translator_reset_path 1 0
force -freeze $datapath_lvds_reset_path 1 0
force -freeze $datapath_mutrig_reset_path 1 0
run 340ns
noforce $datapath_master_clk_reset_path
noforce $datapath_translator_reset_path
noforce $datapath_lvds_reset_path
noforce $datapath_mutrig_reset_path
run -all
quit -f
EOF

echo "═══ Running FE SciFi v3 datapath E2E harness ═══"
run_vsim_logged "${LOG_FILE}" \
  "${VSIM}" -c -do "${VSIM_DO}" \
  -work "${WORK_LIB}" -t ps -voptargs=+acc \
  -suppress 19 -suppress 3009 -suppress 3473 -suppress 12110 -nodpiexports \
  -L altera_ver -L altera_mf_ver -L altera_lnsim_ver -L lpm_ver -L 220model_ver -L twentynm_ver -L sgate_ver \
  "${EXTRA_VSIM_ARGS[@]}" \
  tb_scifi_dp_v3_emu_smoke
