#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

setup_questa_license

DOMAIN="sc"
prepare_domain_tree "${DOMAIN}"

BUILD_DIR="$(work_dir "${DOMAIN}")"
GEN_DIR="$(generated_dir "${DOMAIN}")"
REPORT_DIR="$(report_dir "${DOMAIN}")"
SRC_DIR="${GEN_DIR}/src"
QUIET_RTL_DIR="${GEN_DIR}/quiet_rtl"
WORK_LIB="${BUILD_DIR}/work_sc"
SMOKE_LOG="${REPORT_DIR}/run_sc_smoke.log"
BURST_LOG="${REPORT_DIR}/run_sc_burst_vs_single.log"

mkdir -p "${BUILD_DIR}" "${SRC_DIR}" "${QUIET_RTL_DIR}" "${REPORT_DIR}"
python3 "${SCRIPT_DIR}/derive_v3_benches.py" \
  --case sc_smoke \
  --out-dir "${SRC_DIR}" \
  --feb-entity "${FEB_TARGET_ENTITY}" \
  --scratchpad-prefix "${FEB_TARGET_ENTITY}"
python3 "${SCRIPT_DIR}/derive_v3_benches.py" \
  --case sc_burst_vs_single \
  --out-dir "${SRC_DIR}" \
  --feb-entity "${FEB_TARGET_ENTITY}" \
  --scratchpad-prefix "${FEB_TARGET_ENTITY}"
python3 "${SCRIPT_DIR}/prepare_quiet_timing_adapters.py" \
  --qip "${FEB_QIP}" \
  --synth-dir "${FEB_SYNTH}" \
  --out-dir "${QUIET_RTL_DIR}"

echo "═══ Compiling FE SciFi v3 SC harnesses ═══"
cd "${BUILD_DIR}"
rm -f transcript vsim.wlf
create_work_lib "${WORK_LIB}"
map_intel_libs "${WORK_LIB}"

compile_common_fw_deps "${WORK_LIB}"
run_vlog -work "${WORK_LIB}" "${STATIC_TB_DIR}/arriav_tsdblock_stub.v"
compile_feb_sim_overrides "${WORK_LIB}"
compile_qip "${WORK_LIB}" "${FEB_SYNTH}" "${FEB_QIP}" "${FEB_TARGET_ENTITY}" '(alt_dpram\.vhd|timing_adapter_[0-9]+\.sv|timing_adt\.sv)$'
while IFS= read -r f; do
  run_vlog -work "${WORK_LIB}" \
    -L altera_ver -L altera_mf_ver -L altera_lnsim_ver -L lpm_ver -L 220model_ver -L twentynm_ver -L sgate_ver \
    -sv "${f}"
done < <(find "${QUIET_RTL_DIR}" -maxdepth 1 -type f -name '*.sv' | sort)
run_vcom -work "${WORK_LIB}" -2008 "${SRC_DIR}/tb_feb_system_sc_smoke.vhd"
run_vcom -work "${WORK_LIB}" -2008 "${SRC_DIR}/tb_sc_dp_burst_vs_single.vhd"
symlink_init_files "${BUILD_DIR}" "${FEB_SYNTH}"
materialize_mif_runtime_aliases "${BUILD_DIR}"

read -r -d '' SC_SMOKE_DO <<'EOF' || true
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
set sc_smoke_translator_reset_path [first_existing_path [list \
  /tb_feb_system_sc_smoke/dut/data_path_subsystem/mm_interconnect_1/mm_pipeline_jtagmaster2rstctrl_reset_reset_bridge_in_reset_reset \
  /tb_feb_system_sc_smoke/dut/data_path_subsystem/mm_interconnect_1/master_datapath_master_translator_reset_reset_bridge_in_reset_reset]]
set sc_smoke_master_reset_path [first_existing_path [list \
  /tb_feb_system_sc_smoke/dut/data_path_subsystem/master_datapath/master_reset_reset \
  /tb_feb_system_sc_smoke/dut/data_path_subsystem/master_datapath_master_reset_reset]]
set sc_smoke_master_clk_reset_path [first_existing_path [list \
  /tb_feb_system_sc_smoke/dut/data_path_subsystem/mm_interconnect_1/master_datapath_clk_reset_reset_bridge_in_reset_reset \
  /tb_feb_system_sc_smoke/dut/data_path_subsystem/mm_interconnect_0/master_datapath_clk_reset_reset_bridge_in_reset_reset]]
set sc_smoke_lvds_reset_path [first_existing_path [list \
  /tb_feb_system_sc_smoke/dut/data_path_subsystem/mm_interconnect_1/mm_pipeline_lvds_csr_reset_reset_bridge_in_reset_reset \
  /tb_feb_system_sc_smoke/dut/data_path_subsystem/mm_interconnect_0/mm_pipeline_lvds_csr_reset_reset_bridge_in_reset_reset \
  /tb_feb_system_sc_smoke/dut/data_path_subsystem/mm_interconnect_1/mm_pipeline_avmm_lvds_reset_reset_bridge_in_reset_reset \
  /tb_feb_system_sc_smoke/dut/data_path_subsystem/mm_interconnect_0/mm_pipeline_avmm_lvds_reset_reset_bridge_in_reset_reset]]
set sc_smoke_mutrig_reset_path [first_existing_path [list \
  /tb_feb_system_sc_smoke/dut/data_path_subsystem/mm_interconnect_1/mutrig_datapath_subsystem_0_reset_reset_bridge_in_reset_reset \
  /tb_feb_system_sc_smoke/dut/data_path_subsystem/mm_interconnect_0/mutrig_datapath_subsystem_0_reset_reset_bridge_in_reset_reset]]
set sc_smoke_charge_injection_reset_path [first_existing_path [list \
  /tb_feb_system_sc_smoke/dut/control_path_subsystem/mm_interconnect_0/charge_injection_pulser_0_reset_interface_reset_bridge_in_reset_reset]]
force -freeze $sc_smoke_master_reset_path 0 0
force -freeze $sc_smoke_master_clk_reset_path 1 0
force -freeze $sc_smoke_translator_reset_path 1 0
force -freeze $sc_smoke_lvds_reset_path 1 0
force -freeze $sc_smoke_mutrig_reset_path 1 0
force -freeze $sc_smoke_charge_injection_reset_path 1 0
run 340ns
noforce $sc_smoke_master_clk_reset_path
noforce $sc_smoke_translator_reset_path
noforce $sc_smoke_lvds_reset_path
noforce $sc_smoke_mutrig_reset_path
noforce $sc_smoke_charge_injection_reset_path
run -all
quit -f
EOF

read -r -d '' BURST_DO <<'EOF' || true
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
set sc_burst_translator_reset_path [first_existing_path [list \
  /tb_sc_dp_burst_vs_single/dut/data_path_subsystem/mm_interconnect_1/mm_pipeline_jtagmaster2rstctrl_reset_reset_bridge_in_reset_reset \
  /tb_sc_dp_burst_vs_single/dut/data_path_subsystem/mm_interconnect_1/master_datapath_master_translator_reset_reset_bridge_in_reset_reset]]
set sc_burst_master_reset_path [first_existing_path [list \
  /tb_sc_dp_burst_vs_single/dut/data_path_subsystem/master_datapath/master_reset_reset \
  /tb_sc_dp_burst_vs_single/dut/data_path_subsystem/master_datapath_master_reset_reset]]
set sc_burst_master_clk_reset_path [first_existing_path [list \
  /tb_sc_dp_burst_vs_single/dut/data_path_subsystem/mm_interconnect_1/master_datapath_clk_reset_reset_bridge_in_reset_reset \
  /tb_sc_dp_burst_vs_single/dut/data_path_subsystem/mm_interconnect_0/master_datapath_clk_reset_reset_bridge_in_reset_reset]]
set sc_burst_lvds_reset_path [first_existing_path [list \
  /tb_sc_dp_burst_vs_single/dut/data_path_subsystem/mm_interconnect_1/mm_pipeline_lvds_csr_reset_reset_bridge_in_reset_reset \
  /tb_sc_dp_burst_vs_single/dut/data_path_subsystem/mm_interconnect_0/mm_pipeline_lvds_csr_reset_reset_bridge_in_reset_reset \
  /tb_sc_dp_burst_vs_single/dut/data_path_subsystem/mm_interconnect_1/mm_pipeline_avmm_lvds_reset_reset_bridge_in_reset_reset \
  /tb_sc_dp_burst_vs_single/dut/data_path_subsystem/mm_interconnect_0/mm_pipeline_avmm_lvds_reset_reset_bridge_in_reset_reset]]
set sc_burst_mutrig_reset_path [first_existing_path [list \
  /tb_sc_dp_burst_vs_single/dut/data_path_subsystem/mm_interconnect_1/mutrig_datapath_subsystem_0_reset_reset_bridge_in_reset_reset \
  /tb_sc_dp_burst_vs_single/dut/data_path_subsystem/mm_interconnect_0/mutrig_datapath_subsystem_0_reset_reset_bridge_in_reset_reset]]
set sc_burst_charge_injection_reset_path [first_existing_path [list \
  /tb_sc_dp_burst_vs_single/dut/control_path_subsystem/mm_interconnect_0/charge_injection_pulser_0_reset_interface_reset_bridge_in_reset_reset]]
force -freeze $sc_burst_master_reset_path 0 0
force -freeze $sc_burst_master_clk_reset_path 1 0
force -freeze $sc_burst_translator_reset_path 1 0
force -freeze $sc_burst_lvds_reset_path 1 0
force -freeze $sc_burst_mutrig_reset_path 1 0
force -freeze $sc_burst_charge_injection_reset_path 1 0
run 340ns
noforce $sc_burst_master_clk_reset_path
noforce $sc_burst_translator_reset_path
noforce $sc_burst_lvds_reset_path
noforce $sc_burst_mutrig_reset_path
noforce $sc_burst_charge_injection_reset_path
run -all
quit -f
EOF

echo "═══ Running FE SciFi v3 SC smoke harness ═══"
sc_smoke_vsim_cmd=(
  "${VSIM}" -c -do "${SC_SMOKE_DO}"
  -work "${WORK_LIB}" -t ps -voptargs=+acc
  -suppress 19 -suppress 3009 -suppress 3473 -suppress 12110 -nodpiexports
  -L altera_ver -L altera_mf_ver -L altera_lnsim_ver -L lpm_ver -L 220model_ver -L twentynm_ver -L sgate_ver
  tb_feb_system_sc_smoke
)
run_vsim_logged "${SMOKE_LOG}" "${sc_smoke_vsim_cmd[@]}"

echo "═══ Running FE SciFi v3 SC burst-vs-single harness ═══"
sc_burst_vsim_cmd=(
  "${VSIM}" -c -do "${BURST_DO}"
  -work "${WORK_LIB}" -t ps -voptargs=+acc
  -suppress 19 -suppress 3009 -suppress 3473 -suppress 12110 -nodpiexports
  -L altera_ver -L altera_mf_ver -L altera_lnsim_ver -L lpm_ver -L 220model_ver -L twentynm_ver -L sgate_ver
  tb_sc_dp_burst_vs_single
)
run_vsim_logged "${BURST_LOG}" "${sc_burst_vsim_cmd[@]}"
