#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

setup_questa_license

DOMAIN="soak"
prepare_domain_tree "${DOMAIN}"

BUILD_DIR="$(work_dir "${DOMAIN}")"
GEN_DIR="$(generated_dir "${DOMAIN}")"
REPORT_DIR="$(report_dir "${DOMAIN}")"
QUIET_RTL_DIR="${GEN_DIR}/quiet_rtl"
QUIET_DP_TOP="${QUIET_RTL_DIR}/feb_system_v3_data_path_subsystem.vhd"
WORK_LIB="${BUILD_DIR}/work_soak"
LOG_FILE="${REPORT_DIR}/run_soak.log"
SOAK_TIME_SCALE="${SOAK_TIME_SCALE:-1}"
SOAK_CLK156_PERIOD_BASE="${SOAK_CLK156_PERIOD:-6.4ns}"
SOAK_CLK125_PERIOD_BASE="${SOAK_CLK125_PERIOD:-8ns}"
SOAK_CLK50_PERIOD_BASE="${SOAK_CLK50_PERIOD:-20ns}"
SOAK_RESET_ASSERT_TIME_BASE="${SOAK_RESET_ASSERT_TIME:-200ns}"
SOAK_POST_RESET_SETTLE_BASE="${SOAK_POST_RESET_SETTLE:-5us}"
SOAK_ACTIVE_TIME_BASE="${SOAK_ACTIVE_TIME:-2ms}"
SOAK_STATUS_INTERVAL_BASE="${SOAK_STATUS_INTERVAL:-1ms}"
SOAK_SC_HEALTH_INTERVAL_BASE="${SOAK_SC_HEALTH_INTERVAL:-10ms}"
SOAK_START_SETTLE_BASE="${SOAK_START_SETTLE:-20us}"
SOAK_DRAIN_TIME_BASE="${SOAK_DRAIN_TIME:-40us}"
SOAK_ENABLE_SC_HEALTH="${SOAK_ENABLE_SC_HEALTH:-1}"
SOAK_RESET_FORCE_TIME_BASE="${SOAK_RESET_FORCE_TIME:-340ns}"
SOAK_VSIM_WAIT_STEP_BASE="${SOAK_VSIM_WAIT_STEP:-${SOAK_CLK125_PERIOD_BASE}}"
SOAK_EMU_ACTIVE_MASK="${SOAK_EMU_ACTIVE_MASK:-255}"
SOAK_EMU_HIT_RATE="${SOAK_EMU_HIT_RATE:-2048}"
SOAK_EMU_NOISE_RATE="${SOAK_EMU_NOISE_RATE:-0}"
SOAK_EMU_TIMING_WORD="${SOAK_EMU_TIMING_WORD:-131076}"
SOAK_EMU_CFG_LOCAL="${SOAK_EMU_CFG_LOCAL:-auto}"
SOAK_EMU_CFG_FAST_FORCE="${SOAK_EMU_CFG_FAST_FORCE:-0}"
SOAK_USE_PLL_STUB="${SOAK_USE_PLL_STUB:-auto}"
SOAK_FORCE_LVDS_OUTCLOCK="${SOAK_FORCE_LVDS_OUTCLOCK:-auto}"
SOAK_GATE_IDLE_DECODE="${SOAK_GATE_IDLE_DECODE:-1}"
SOAK_PROGRESS_HEARTBEAT_CYCLES="${SOAK_PROGRESS_HEARTBEAT_CYCLES:-0}"
SOAK_SKIP_BUILD="${SOAK_SKIP_BUILD:-0}"

scale_time_literal() {
  python3 - "$1" "$2" <<'PY'
import decimal
import re
import sys

literal = sys.argv[1]
scale = decimal.Decimal(sys.argv[2])
match = re.fullmatch(r'([0-9]+(?:\.[0-9]+)?)([a-zA-Z]+)', literal)
if match is None:
    raise SystemExit(f"bad time literal: {literal}")

scaled = decimal.Decimal(match.group(1)) * scale
text = format(scaled, 'f')
if '.' in text:
    text = text.rstrip('0').rstrip('.')
print(f"{text}{match.group(2)}")
PY
}

SOAK_CLK156_PERIOD="$(scale_time_literal "${SOAK_CLK156_PERIOD_BASE}" "${SOAK_TIME_SCALE}")"
SOAK_CLK125_PERIOD="$(scale_time_literal "${SOAK_CLK125_PERIOD_BASE}" "${SOAK_TIME_SCALE}")"
SOAK_CLK50_PERIOD="$(scale_time_literal "${SOAK_CLK50_PERIOD_BASE}" "${SOAK_TIME_SCALE}")"
SOAK_RESET_ASSERT_TIME="$(scale_time_literal "${SOAK_RESET_ASSERT_TIME_BASE}" "${SOAK_TIME_SCALE}")"
SOAK_POST_RESET_SETTLE="$(scale_time_literal "${SOAK_POST_RESET_SETTLE_BASE}" "${SOAK_TIME_SCALE}")"
SOAK_ACTIVE_TIME="$(scale_time_literal "${SOAK_ACTIVE_TIME_BASE}" "${SOAK_TIME_SCALE}")"
SOAK_STATUS_INTERVAL="$(scale_time_literal "${SOAK_STATUS_INTERVAL_BASE}" "${SOAK_TIME_SCALE}")"
SOAK_SC_HEALTH_INTERVAL="$(scale_time_literal "${SOAK_SC_HEALTH_INTERVAL_BASE}" "${SOAK_TIME_SCALE}")"
SOAK_START_SETTLE="$(scale_time_literal "${SOAK_START_SETTLE_BASE}" "${SOAK_TIME_SCALE}")"
SOAK_DRAIN_TIME="$(scale_time_literal "${SOAK_DRAIN_TIME_BASE}" "${SOAK_TIME_SCALE}")"
SOAK_RESET_FORCE_TIME="$(scale_time_literal "${SOAK_RESET_FORCE_TIME_BASE}" "${SOAK_TIME_SCALE}")"
SOAK_VSIM_WAIT_STEP="$(scale_time_literal "${SOAK_VSIM_WAIT_STEP_BASE}" "${SOAK_TIME_SCALE}")"

if [[ "${SOAK_USE_PLL_STUB}" == "auto" ]]; then
  if [[ "${SOAK_TIME_SCALE}" == "1" ]]; then
    SOAK_USE_PLL_STUB="0"
  else
    SOAK_USE_PLL_STUB="1"
  fi
fi

if [[ "${SOAK_EMU_CFG_FAST_FORCE}" == "1" ]]; then
  SOAK_EMU_CFG_FAST_FORCE_BOOL="true"
else
  SOAK_EMU_CFG_FAST_FORCE_BOOL="false"
fi

if [[ "${SOAK_ENABLE_SC_HEALTH}" == "1" ]]; then
  SOAK_ENABLE_SC_HEALTH_BOOL="true"
else
  SOAK_ENABLE_SC_HEALTH_BOOL="false"
fi

if [[ "${SOAK_EMU_CFG_LOCAL}" == "auto" ]]; then
  if [[ "${SOAK_TIME_SCALE}" == "1" ]]; then
    SOAK_EMU_CFG_LOCAL="false"
  else
    SOAK_EMU_CFG_LOCAL="true"
  fi
fi

if [[ "${SOAK_FORCE_LVDS_OUTCLOCK}" == "auto" ]]; then
  if [[ "${SOAK_TIME_SCALE}" == "1" ]]; then
    SOAK_FORCE_LVDS_OUTCLOCK="0"
  else
    SOAK_FORCE_LVDS_OUTCLOCK="1"
  fi
fi

mkdir -p "${BUILD_DIR}" "${QUIET_RTL_DIR}" "${REPORT_DIR}"
if [[ "${SOAK_SKIP_BUILD}" != "1" ]]; then
  python3 "${SCRIPT_DIR}/prepare_quiet_timing_adapters.py" \
    --qip "${FEB_QIP}" \
    --synth-dir "${FEB_SYNTH}" \
    --out-dir "${QUIET_RTL_DIR}"

  # The generated FEB datapath wrapper enables verbose MTS debug tracing by
  # default. Keep the source Qsys untouched and compile a local quiet copy for
  # the long-run integration soak.
  sed -E 's/(DEBUG[[:space:]]*=>)[[:space:]]*1/\1 0/g' \
    "${FEB_SYNTH}/submodules/feb_system_v3_data_path_subsystem.vhd" \
    > "${QUIET_DP_TOP}"

  echo "═══ Compiling FE SciFi v3 soak harness ═══"
  cd "${BUILD_DIR}"
  rm -f transcript vsim.wlf
  create_work_lib "${WORK_LIB}"
  map_intel_libs "${WORK_LIB}"

  compile_common_fw_deps "${WORK_LIB}"
  run_vlog -work "${WORK_LIB}" "${STATIC_TB_DIR}/arriav_tsdblock_stub.v"
  compile_feb_sim_overrides "${WORK_LIB}"
  compile_qip "${WORK_LIB}" "${FEB_SYNTH}" "${FEB_QIP}" "feb_system_v3" '(alt_dpram\.vhd|timing_adapter_[0-9]+\.sv|timing_adt\.sv)$'
  if [[ "${SOAK_USE_PLL_STUB}" == "1" ]]; then
    run_vlog -work "${WORK_LIB}" "${STATIC_TB_DIR}/feb_system_v3_control_path_subsystem_pll_156t40_stub.v"
  fi
  run_vcom -work "${WORK_LIB}" -2008 "${QUIET_DP_TOP}"
  while IFS= read -r f; do
    run_vlog -work "${WORK_LIB}" \
      -L altera_ver -L altera_mf_ver -L altera_lnsim_ver -L lpm_ver -L 220model_ver -L twentynm_ver -L sgate_ver \
      -sv "${f}"
  done < <(find "${QUIET_RTL_DIR}" -maxdepth 1 -type f -name '*.sv' | sort)
  run_vcom -work "${WORK_LIB}" -2008 "${STATIC_TB_DIR}/swb_phy_ingress_stub.vhd"
  run_vcom -work "${WORK_LIB}" -2008 "${STATIC_TB_DIR}/tb_feb_system_v3_soak.vhd"
  run_vlog -work "${WORK_LIB}" -sv "${STATIC_TB_DIR}/tb_feb_system_v3_soak_sidecar.sv"
  symlink_init_files "${BUILD_DIR}" "${FEB_SYNTH}"
  materialize_mif_runtime_aliases "${BUILD_DIR}"
else
  echo "═══ Reusing FE SciFi v3 soak harness build ═══"
  cd "${BUILD_DIR}"
fi

echo "═══ Soak timing configuration ═══"
echo "scale=${SOAK_TIME_SCALE}"
echo "clk156=${SOAK_CLK156_PERIOD} clk125=${SOAK_CLK125_PERIOD} clk50=${SOAK_CLK50_PERIOD}"
echo "use_pll_stub=${SOAK_USE_PLL_STUB}"
echo "emu_cfg_local=${SOAK_EMU_CFG_LOCAL}"
echo "emu_cfg_fast_force=${SOAK_EMU_CFG_FAST_FORCE_BOOL}"
echo "enable_sc_health=${SOAK_ENABLE_SC_HEALTH_BOOL}"
echo "force_lvds_outclock=${SOAK_FORCE_LVDS_OUTCLOCK}"
echo "progress_heartbeat_cycles=${SOAK_PROGRESS_HEARTBEAT_CYCLES}"
echo "reset_assert=${SOAK_RESET_ASSERT_TIME} post_reset_settle=${SOAK_POST_RESET_SETTLE} force_reset=${SOAK_RESET_FORCE_TIME}"
echo "active=${SOAK_ACTIVE_TIME} status=${SOAK_STATUS_INTERVAL} sc_health=${SOAK_SC_HEALTH_INTERVAL} start_settle=${SOAK_START_SETTLE} drain=${SOAK_DRAIN_TIME}"

declare -a VSIM_PLUSARGS=()
if [[ "${SOAK_GATE_IDLE_DECODE}" == "1" ]]; then
  VSIM_PLUSARGS+=(+SOAK_GATE_IDLE_DECODE)
fi

read -r -d '' VSIM_DO <<'EOF' || true
quietly set NumericStdNoWarnings 1
quietly set StdArithNoWarnings 1
onbreak {quit -code 1 -f}
proc trim_examine {path {radix ""}} {
  if {$radix eq ""} {
    return [string trim [examine $path]]
  }
  return [string trim [examine -radix $radix $path]]
}
proc wait_cycles_for_value {path expected cycles step label {radix ""}} {
  for {set i 0} {$i < $cycles} {incr i} {
    if {[trim_examine $path $radix] eq $expected} {
      return 1
    }
    run $step
  }
  puts "ERROR: timeout waiting for $label ($path == $expected)"
  return 0
}
proc first_existing_path {paths} {
  foreach path $paths {
    if {![catch {examine $path}]} {
      return $path
    }
  }
  puts "ERROR: none of the candidate paths exist: $paths"
  quit -code 1 -f
}
proc force_idle_if_exists {path value} {
  if {![catch {examine $path}]} {
    force -freeze $path $value 0
  }
}
proc rc_force_group {valid data} {
  for {set idx 0} {$idx < 16} {incr idx} {
    force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/run_control_splitter_out${idx}_valid $valid 0
    force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/run_control_splitter_out${idx}_data  $data  0
  }

  for {set idx 0} {$idx < 9} {incr idx} {
    force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/emulator_ctrl_splitter_out${idx}_valid $valid 0
    force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/emulator_ctrl_splitter_out${idx}_data  $data  0
  }

  foreach prefix [list \
    /tb_feb_system_v3_soak/dut/data_path_subsystem/histogram_statistics_0/asi_ctrl \
    /tb_feb_system_v3_soak/dut/data_path_subsystem/mts_preprocessor_0/asi_ctrl \
    /tb_feb_system_v3_soak/dut/data_path_subsystem/hit_stack_subsystem_0/run_control_signal \
    /tb_feb_system_v3_soak/dut/data_path_subsystem/mutrig_reset_controller_0/asi_runcontrol \
    /tb_feb_system_v3_soak/dut/data_path_subsystem/mts_preprocessor_1/asi_ctrl \
    /tb_feb_system_v3_soak/dut/data_path_subsystem/mutrig_injector_0/asi_runctl \
    /tb_feb_system_v3_soak/dut/data_path_subsystem/hit_stack_subsystem_1/run_control_signal \
    /tb_feb_system_v3_soak/dut/data_path_subsystem/histogram_statistics_1/asi_ctrl \
  ] {
    force -freeze ${prefix}_valid $valid 0
    force -freeze ${prefix}_data  $data  0
  }

  for {set lane 0} {$lane < 8} {incr lane} {
    force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/mutrig_datapath_subsystem_${lane}/run_ctrl_valid $valid 0
    force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/mutrig_datapath_subsystem_${lane}/run_ctrl_data  $data  0
    force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/emulator_mutrig_${lane}/asi_ctrl_valid          $valid 0
    force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/emulator_mutrig_${lane}/asi_ctrl_data           $data  0
  }

  for {set hs 0} {$hs < 2} {incr hs} {
    force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/hit_stack_subsystem_${hs}/run_control_signal_valid $valid 0
    force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/hit_stack_subsystem_${hs}/run_control_signal_data  $data  0
    for {set out 0} {$out < 5} {incr out} {
      force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/hit_stack_subsystem_${hs}/run_control_splitter_0_out${out}_valid $valid 0
      force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/hit_stack_subsystem_${hs}/run_control_splitter_0_out${out}_data  $data  0
    }
    force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/hit_stack_subsystem_${hs}/run_ctrl_cdc_d2x_out_valid $valid 0
    force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/hit_stack_subsystem_${hs}/run_ctrl_cdc_d2x_out_data  $data  0
  }
}
proc rc_pulse {data duration} {
  rc_force_group 1 $data
  run $duration
  rc_force_group 0 $data
}
proc report_rc_probes {tag} {
  foreach path [list \
    /tb_feb_system_v3_soak/dut/data_path_subsystem/run_control_splitter_out6_valid \
    /tb_feb_system_v3_soak/dut/data_path_subsystem/run_control_splitter_out6_data \
    /tb_feb_system_v3_soak/dut/data_path_subsystem/histogram_statistics_0/asi_ctrl_valid \
    /tb_feb_system_v3_soak/dut/data_path_subsystem/histogram_statistics_0/asi_ctrl_data \
    /tb_feb_system_v3_soak/dut/data_path_subsystem/hit_stack_subsystem_0/run_control_signal_valid \
    /tb_feb_system_v3_soak/dut/data_path_subsystem/hit_stack_subsystem_0/run_control_signal_data \
    /tb_feb_system_v3_soak/dut/data_path_subsystem/hit_stack_subsystem_0/run_control_splitter_0_out4_valid \
    /tb_feb_system_v3_soak/dut/data_path_subsystem/hit_stack_subsystem_0/run_control_splitter_0_out4_data \
    /tb_feb_system_v3_soak/dut/data_path_subsystem/hit_stack_subsystem_0/run_ctrl_cdc_d2x_out_valid \
    /tb_feb_system_v3_soak/dut/data_path_subsystem/hit_stack_subsystem_0/run_ctrl_cdc_d2x_out_data \
    /tb_feb_system_v3_soak/dut/data_path_subsystem/hit_stack_subsystem_1/run_control_signal_valid \
    /tb_feb_system_v3_soak/dut/data_path_subsystem/hit_stack_subsystem_1/run_control_signal_data \
    /tb_feb_system_v3_soak/dut/data_path_subsystem/hit_stack_subsystem_1/run_control_splitter_0_out4_valid \
    /tb_feb_system_v3_soak/dut/data_path_subsystem/hit_stack_subsystem_1/run_control_splitter_0_out4_data \
    /tb_feb_system_v3_soak/dut/data_path_subsystem/hit_stack_subsystem_1/run_ctrl_cdc_d2x_out_valid \
    /tb_feb_system_v3_soak/dut/data_path_subsystem/hit_stack_subsystem_1/run_ctrl_cdc_d2x_out_data \
  ] {
    if {[catch {set value [trim_examine $path binary]}]} {
      puts "DBG $tag $path = <missing>"
    } else {
      puts "DBG $tag $path = $value"
    }
  }
}
set translator_reset_path [first_existing_path [list \
  /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_interconnect_1/mm_pipeline_jtagmaster2rstctrl_reset_reset_bridge_in_reset_reset \
  /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_interconnect_1/master_datapath_master_translator_reset_reset_bridge_in_reset_reset]]
set soak_master_reset_path [first_existing_path [list \
  /tb_feb_system_v3_soak/dut/data_path_subsystem/master_datapath/master_reset_reset \
  /tb_feb_system_v3_soak/dut/data_path_subsystem/master_datapath_master_reset_reset]]
set soak_master_clk_reset_path [first_existing_path [list \
  /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_interconnect_1/master_datapath_clk_reset_reset_bridge_in_reset_reset \
  /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_interconnect_0/master_datapath_clk_reset_reset_bridge_in_reset_reset]]
set soak_lvds_reset_path [first_existing_path [list \
  /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_interconnect_1/mm_pipeline_lvds_csr_reset_reset_bridge_in_reset_reset \
  /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_interconnect_0/mm_pipeline_lvds_csr_reset_reset_bridge_in_reset_reset \
  /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_interconnect_1/mm_pipeline_avmm_lvds_reset_reset_bridge_in_reset_reset \
  /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_interconnect_0/mm_pipeline_avmm_lvds_reset_reset_bridge_in_reset_reset]]
set soak_mutrig_reset_path [first_existing_path [list \
  /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_interconnect_1/mutrig_datapath_subsystem_0_reset_reset_bridge_in_reset_reset \
  /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_interconnect_0/mutrig_datapath_subsystem_0_reset_reset_bridge_in_reset_reset]]
force -freeze $soak_master_reset_path 0 0
force -freeze $soak_master_clk_reset_path 1 0
force -freeze $translator_reset_path 1 0
force -freeze $soak_lvds_reset_path 1 0
force -freeze $soak_mutrig_reset_path 1 0
# The hit-stack generated reset controllers do not always see a clean startup
# pulse in this mixed-language image. Force them through the initial reset
# window so the ring-buffer-cam and frame-assembly leaves take their reset
# defaults deterministically.
force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/hit_stack_subsystem_0/rst_controller_reset_out_reset 1 0
force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/hit_stack_subsystem_1/rst_controller_reset_out_reset 1 0
force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/hit_stack_subsystem_0/rst_controller_001_reset_out_reset 1 0
force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/hit_stack_subsystem_1/rst_controller_001_reset_out_reset 1 0
run __SOAK_RESET_FORCE_TIME__
noforce $soak_master_clk_reset_path
noforce $translator_reset_path
noforce $soak_lvds_reset_path
noforce $soak_mutrig_reset_path
noforce /tb_feb_system_v3_soak/dut/data_path_subsystem/hit_stack_subsystem_0/rst_controller_reset_out_reset
noforce /tb_feb_system_v3_soak/dut/data_path_subsystem/hit_stack_subsystem_1/rst_controller_reset_out_reset
noforce /tb_feb_system_v3_soak/dut/data_path_subsystem/hit_stack_subsystem_0/rst_controller_001_reset_out_reset
noforce /tb_feb_system_v3_soak/dut/data_path_subsystem/hit_stack_subsystem_1/rst_controller_001_reset_out_reset

if {__SOAK_FORCE_LVDS_OUTCLOCK__} {
  force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/lvds_rx_28nm_0_outclock_clk 0 0, 1 __SOAK_LVDS_OUTCLOCK_HALF_PERIOD__ -repeat __SOAK_LVDS_OUTCLOCK_PERIOD__
  force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem_lvds_outclock_clk 0 0, 1 __SOAK_LVDS_OUTCLOCK_HALF_PERIOD__ -repeat __SOAK_LVDS_OUTCLOCK_PERIOD__
}

# The generated LVDS MM pipeline leaves sideband signals X while idle-low.
# Pin the unused master idle so the datapath interconnect decoder stays stable.
force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_pipeline_avmm_lvds_m0_address 0 0
force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_pipeline_avmm_lvds_m0_burstcount 2#000000001 0
force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_pipeline_avmm_lvds_m0_byteenable 2#1111 0
force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_pipeline_avmm_lvds_m0_writedata 16#00000000 0
force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_pipeline_avmm_lvds_m0_debugaccess 0 0
force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_pipeline_avmm_lvds_m0_read 0 0
force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_pipeline_avmm_lvds_m0_write 0 0

# Keep the generated datapath slave seams explicitly idle. In this mixed
# VHDL/SV image the inactive interconnect nets can otherwise stay X and
# poison external SC accesses into the datapath bridge.
for {set lane 0} {$lane < 8} {incr lane} {
  force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_interconnect_1_mutrig_datapath_subsystem_${lane}_backpressure_fifo_csr_address 0 0
  force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_interconnect_1_mutrig_datapath_subsystem_${lane}_backpressure_fifo_csr_read 0 0
  force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_interconnect_1_mutrig_datapath_subsystem_${lane}_backpressure_fifo_csr_write 0 0
  force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_interconnect_1_mutrig_datapath_subsystem_${lane}_backpressure_fifo_csr_writedata 16#00000000 0
  force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_interconnect_1_mutrig_datapath_subsystem_${lane}_csr_address 0 0
  force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_interconnect_1_mutrig_datapath_subsystem_${lane}_csr_read 0 0
  force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_interconnect_1_mutrig_datapath_subsystem_${lane}_csr_write 0 0
  force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_interconnect_1_mutrig_datapath_subsystem_${lane}_csr_writedata 16#00000000 0
}

foreach seam [list \
  lvds_rx_controller_pro_0_csr \
  mts_preprocessor_0_csr \
  mts_preprocessor_1_csr \
  hit_stack_subsystem_0_ring_buffer_cam_0_csr \
  hit_stack_subsystem_0_ring_buffer_cam_1_csr \
  hit_stack_subsystem_0_ring_buffer_cam_2_csr \
  hit_stack_subsystem_0_ring_buffer_cam_3_csr \
  hit_stack_subsystem_1_ring_buffer_cam_0_csr \
  hit_stack_subsystem_1_ring_buffer_cam_1_csr \
  hit_stack_subsystem_1_ring_buffer_cam_2_csr \
  hit_stack_subsystem_1_ring_buffer_cam_3_csr \
  hit_stack_subsystem_0_feb_frame_assembly_csr \
  hit_stack_subsystem_1_feb_frame_assembly_csr \
  mutrig_injector_0_csr \
  mutrig_reset_controller_0_reconfig_mgmt \
] {
  force_idle_if_exists /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_interconnect_1_${seam}_address 0
  force_idle_if_exists /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_interconnect_1_${seam}_read 0
  force_idle_if_exists /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_interconnect_1_${seam}_write 0
  force_idle_if_exists /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_interconnect_1_${seam}_writedata 16#00000000
  force_idle_if_exists /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_interconnect_1_${seam}_burstcount 2#000000001
}

foreach seam [list histogram_statistics_0_hist_bin histogram_statistics_1_hist_bin] {
  force_idle_if_exists /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_interconnect_1_${seam}_address 0
  force_idle_if_exists /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_interconnect_1_${seam}_read 0
  force_idle_if_exists /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_interconnect_1_${seam}_write 0
  force_idle_if_exists /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_interconnect_1_${seam}_writedata 16#00000000
  force_idle_if_exists /tb_feb_system_v3_soak/dut/data_path_subsystem/mm_interconnect_1_${seam}_burstcount 2#000000001
}

force_idle_if_exists /tb_feb_system_v3_soak/dut/data_path_subsystem/histogram_statistics_0_fill_out_ready 1
for {set lane 1} {$lane < 8} {incr lane} {
  force_idle_if_exists /tb_feb_system_v3_soak/dut/data_path_subsystem/hist_rate_splitter_${lane}_out0_ready 1
}
for {set lane 0} {$lane < 8} {incr lane} {
  force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/mutrig_datapath_subsystem_${lane}_hit_type0_out_ready 1 0
}

# Disable the broken generated LVDS decode leg in simulation so the merged
# emulator path is the only live decoded source.
foreach seam [list 029 032 035 038 041 044 047 050] {
  force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/avalon_st_adapter_${seam}_out_0_valid 0 0
  force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/avalon_st_adapter_${seam}_out_0_data 0 0
  force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/avalon_st_adapter_${seam}_out_0_channel 0 0
  force -freeze /tb_feb_system_v3_soak/dut/data_path_subsystem/avalon_st_adapter_${seam}_out_0_error 0 0
}

if {__SOAK_FAST_EMU_CFG__} {
  for {set lane 0} {$lane < 8} {incr lane} {
    set base /tb_feb_system_v3_soak/dut/data_path_subsystem/emulator_mutrig_${lane}
    set seed_word [format 16#%08X [expr {0x1BADF00D ^ $lane}]]
    set asic_word [format 16#%X $lane]
    foreach {suffix value} [list \
      csr_enable 1 \
      csr_hit_mode 2#00 \
      csr_short_mode 0 \
      csr_hit_rate 16#0800 \
      csr_noise_rate 16#0000 \
      csr_prng_seed $seed_word \
      csr_tx_mode 2#000 \
      csr_gen_idle 1 \
      csr_asic_id $asic_word \
    ] {
      if {[catch {force -freeze ${base}/${suffix} $value 0} err]} {
        puts "ERROR: failed to fast-force ${base}/${suffix}: $err"
        quit -code 1 -f
      }
    }
  }
  puts "INFO: fast-forced emulator CSR state for soak stimulus"
}

if {![wait_cycles_for_value /tb_feb_system_v3_soak/external_rc_active 1 500000 __SOAK_VSIM_WAIT_STEP__ "external RC active window"]} {
  quit -code 1 -f
}

for {set idx 0} {$idx < 16} {incr idx} {
  force_idle_if_exists /tb_feb_system_v3_soak/dut/data_path_subsystem/run_control_splitter_out${idx}_ready 1
}
for {set idx 0} {$idx < 9} {incr idx} {
  force_idle_if_exists /tb_feb_system_v3_soak/dut/data_path_subsystem/emulator_ctrl_splitter_out${idx}_ready 1
}
puts "INFO: RC pulse train is driven by tb_feb_system_v3_soak_sidecar.sv"

run -all
quit -f
EOF

VSIM_DO="${VSIM_DO//__SOAK_RESET_FORCE_TIME__/${SOAK_RESET_FORCE_TIME}}"
VSIM_DO="${VSIM_DO//__SOAK_VSIM_WAIT_STEP__/${SOAK_VSIM_WAIT_STEP}}"
VSIM_DO="${VSIM_DO//__SOAK_FORCE_LVDS_OUTCLOCK__/${SOAK_FORCE_LVDS_OUTCLOCK}}"
VSIM_DO="${VSIM_DO//__SOAK_FAST_EMU_CFG__/${SOAK_EMU_CFG_FAST_FORCE}}"
VSIM_DO="${VSIM_DO//__SOAK_LVDS_OUTCLOCK_PERIOD__/${SOAK_CLK125_PERIOD}}"
VSIM_DO="${VSIM_DO//__SOAK_LVDS_OUTCLOCK_HALF_PERIOD__/$(
  python3 - "${SOAK_CLK125_PERIOD}" <<'PY'
import decimal
import re
import sys
literal = sys.argv[1]
match = re.fullmatch(r'([0-9]+(?:\.[0-9]+)?)([a-zA-Z]+)', literal)
if match is None:
    raise SystemExit(f"bad time literal: {literal}")
half = decimal.Decimal(match.group(1)) / decimal.Decimal(2)
text = format(half, 'f')
if '.' in text:
    text = text.rstrip('0').rstrip('.')
print(f"{text}{match.group(2)}")
PY
)}"

echo "═══ Running FE SciFi v3 integrated soak harness ═══"
run_vsim_logged "${LOG_FILE}" \
  "${VSIM}" -c -do "${VSIM_DO}" \
  -work "${WORK_LIB}" -t ps -voptargs=+acc \
  "-gG_CLK156_PERIOD=${SOAK_CLK156_PERIOD}" \
  "-gG_CLK125_PERIOD=${SOAK_CLK125_PERIOD}" \
  "-gG_CLK50_PERIOD=${SOAK_CLK50_PERIOD}" \
  "-gG_RESET_ASSERT_TIME=${SOAK_RESET_ASSERT_TIME}" \
  "-gG_POST_RESET_SETTLE=${SOAK_POST_RESET_SETTLE}" \
  "-gG_SOAK_ACTIVE_TIME=${SOAK_ACTIVE_TIME}" \
  "-gG_SOAK_STATUS_INTERVAL=${SOAK_STATUS_INTERVAL}" \
  "-gG_SOAK_SC_HEALTH_INTERVAL=${SOAK_SC_HEALTH_INTERVAL}" \
  "-gG_SOAK_START_SETTLE=${SOAK_START_SETTLE}" \
  "-gG_SOAK_DRAIN_TIME=${SOAK_DRAIN_TIME}" \
  "-gG_ENABLE_SC_HEALTH=${SOAK_ENABLE_SC_HEALTH_BOOL}" \
  "-gG_EMU_ACTIVE_MASK=${SOAK_EMU_ACTIVE_MASK}" \
  "-gG_EMU_HIT_RATE=${SOAK_EMU_HIT_RATE}" \
  "-gG_EMU_NOISE_RATE=${SOAK_EMU_NOISE_RATE}" \
  "-gG_EMU_TIMING_WORD=${SOAK_EMU_TIMING_WORD}" \
  "-gG_EMU_CFG_LOCAL=${SOAK_EMU_CFG_LOCAL}" \
  "-gG_EMU_CFG_FAST_FORCE=${SOAK_EMU_CFG_FAST_FORCE_BOOL}" \
  "-gG_PROGRESS_HEARTBEAT_CYCLES=${SOAK_PROGRESS_HEARTBEAT_CYCLES}" \
  "${VSIM_PLUSARGS[@]}" \
  -suppress 19 -suppress 3009 -suppress 3473 -suppress 12110 -nodpiexports \
  -L altera_ver -L altera_mf_ver -L altera_lnsim_ver -L lpm_ver -L 220model_ver -L twentynm_ver -L sgate_ver \
  tb_feb_system_v3_soak tb_feb_system_v3_soak_sidecar
