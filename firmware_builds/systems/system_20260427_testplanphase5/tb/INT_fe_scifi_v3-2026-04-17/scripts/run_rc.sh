#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

setup_questa_license

DOMAIN="rc"
prepare_domain_tree "${DOMAIN}"

BUILD_DIR="$(work_dir "${DOMAIN}")"
GEN_DIR="$(generated_dir "${DOMAIN}")"
REPORT_DIR="$(report_dir "${DOMAIN}")"
SRC_DIR="${GEN_DIR}/src"
QUIET_RTL_DIR="${GEN_DIR}/quiet_rtl"
WORK_LIB="${BUILD_DIR}/work_rc"
LOG_FILE="${REPORT_DIR}/run_rc.log"

mkdir -p "${BUILD_DIR}" "${SRC_DIR}" "${QUIET_RTL_DIR}" "${REPORT_DIR}"
python3 "${SCRIPT_DIR}/derive_v3_benches.py" \
  --case feb_to_swb_links \
  --out-dir "${SRC_DIR}" \
  --feb-entity "${FEB_TARGET_ENTITY}" \
  --scratchpad-prefix "${FEB_TARGET_ENTITY}"
python3 "${SCRIPT_DIR}/prepare_quiet_timing_adapters.py" \
  --qip "${FEB_QIP}" \
  --synth-dir "${FEB_SYNTH}" \
  --out-dir "${QUIET_RTL_DIR}"

echo "═══ Compiling FE SciFi v3 RC harness ═══"
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
run_vcom -work "${WORK_LIB}" -2008 "${STATIC_TB_DIR}/swb_phy_ingress_stub.vhd"
run_vcom -work "${WORK_LIB}" -2008 "${SRC_DIR}/tb_feb_to_swb_links.vhd"
symlink_init_files "${BUILD_DIR}" "${FEB_SYNTH}"
materialize_mif_runtime_aliases "${BUILD_DIR}"

read -r -d '' VSIM_DO <<'EOF' || true
quietly set NumericStdNoWarnings 1
quietly set StdArithNoWarnings 1
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
proc wait_cycles_for_at_least {path expected_min cycles step label} {
  for {set i 0} {$i < $cycles} {incr i} {
    if {[sample_nat $path] >= $expected_min} {
      return 1
    }
    run $step
  }
  puts "ERROR: timeout waiting for $label ($path >= $expected_min)"
  return 0
}
proc sample_nat {path} {
  return [expr {[trim_examine $path decimal] + 0}]
}
proc sample_bit {path} {
  set value [trim_examine $path]
  return [expr {$value eq "1"}]
}
proc print_optional_ready {label path} {
  if {[catch {set value [trim_examine $path]}]} {
    puts "INFO: RC_READY optional $label MISSING $path"
  } else {
    puts "INFO: RC_READY optional $label=$value"
  }
}
proc print_rc_ready_snapshot {label} {
  set base /tb_feb_to_swb_links/dut/data_path_subsystem
  set entries [list \
    [list 0  histogram_statistics_0   run_control_splitter_out0_ready] \
    [list 1  mts_preprocessor_0       run_control_splitter_out1_ready] \
    [list 2  mutrig_datapath_0        run_control_splitter_out2_ready] \
    [list 3  mutrig_datapath_1        run_control_splitter_out3_ready] \
    [list 4  mutrig_datapath_2        run_control_splitter_out4_ready] \
    [list 5  mutrig_datapath_3        run_control_splitter_out5_ready] \
    [list 6  hit_stack_0              run_control_splitter_out6_ready] \
    [list 7  mutrig_reset_controller  run_control_splitter_out7_ready] \
    [list 8  mutrig_datapath_4        run_control_splitter_out8_ready] \
    [list 9  mutrig_datapath_5        run_control_splitter_out9_ready] \
    [list 10 mutrig_datapath_6        run_control_splitter_out10_ready] \
    [list 11 mutrig_datapath_7        run_control_splitter_out11_ready] \
    [list 12 mts_preprocessor_1       run_control_splitter_out12_ready] \
    [list 13 mutrig_injector          run_control_splitter_out13_ready] \
    [list 14 hit_stack_1              run_control_splitter_out14_ready] \
    [list 15 emulator_ctrl_splitter   run_control_splitter_out15_ready]]
  set mask 0
  set observed 0
  foreach entry $entries {
    lassign $entry idx name sig
    set path "$base/$sig"
    if {[catch {set value [trim_examine $path]}]} {
      puts [format "INFO: RC_READY %s out%02d %-24s ready=MISSING readyless_broadcast" $label $idx $name]
    } else {
      incr observed
      set bit [expr {$value eq "1"}]
      if {$bit} {
        set mask [expr {$mask | (1 << $idx)}]
      }
      puts [format "INFO: RC_READY %s out%02d %-24s ready=%0d" $label $idx $name $bit]
    }
  }
  if {$observed == 0} {
    puts [format "INFO: RC_READY %s mask=n/a readyless_broadcast top_ready=%s" \
      $label [trim_examine /tb_feb_to_swb_links/dut/upload_subsystem_runctl_mgmt_host_ready]]
  } else {
    puts [format "INFO: RC_READY %s mask=0x%04X observed=%0d top_ready=%s" \
      $label $mask $observed [trim_examine /tb_feb_to_swb_links/dut/upload_subsystem_runctl_mgmt_host_ready]]
  }
  for {set idx 0} {$idx < 9} {incr idx} {
    print_optional_ready "${label} emulator_ctrl_splitter_out${idx}" \
      "$base/emulator_ctrl_splitter_out${idx}_ready"
  }
  foreach hs {0 1} {
    for {set idx 0} {$idx < 6} {incr idx} {
      print_optional_ready "${label} hit_stack_${hs}_out${idx}" \
        "$base/hit_stack_subsystem_${hs}/run_control_splitter_0_out${idx}_ready"
    }
  }
}
proc print_hit_stack_cdc_snapshot {label} {
  set base /tb_feb_to_swb_links/dut/data_path_subsystem
  foreach hs {0 1} {
    set inst "$base/hit_stack_subsystem_${hs}"
    foreach entry [list \
      [list datapath_reset_n datapath_reset_reset_n] \
      [list xcvr_reset_n xcvr_reset_reset_n] \
      [list datapath_rst_in datapath_reset_reset_n_ports_inv] \
      [list xcvr_rst_in xcvr_reset_reset_n_ports_inv] \
      [list datapath_rst_out rst_controller_reset_out_reset] \
      [list xcvr_rst_out rst_controller_001_reset_out_reset] \
      [list fifo_in_reset_n rst_controller_reset_out_reset_ports_inv] \
      [list fifo_out_reset_n rst_controller_001_reset_out_reset_ports_inv] \
      [list cdc_in_ready run_ctrl_cdc_d2x/in_ready] \
      [list cdc_in_valid run_ctrl_cdc_d2x/in_valid] \
      [list cdc_out_ready run_ctrl_cdc_d2x/out_ready] \
      [list cdc_out_valid run_ctrl_cdc_d2x/out_valid] \
      [list cdc_full run_ctrl_cdc_d2x/full] \
      [list cdc_empty run_ctrl_cdc_d2x/empty] \
      [list cdc_sink_in_reset run_ctrl_cdc_d2x/sink_in_reset] \
      [list cdc_in_wr_ptr run_ctrl_cdc_d2x/in_wr_ptr] \
      [list cdc_in_rd_ptr_gray run_ctrl_cdc_d2x/in_rd_ptr_gray] \
      [list cdc_out_rd_ptr run_ctrl_cdc_d2x/out_rd_ptr] \
      [list cdc_out_wr_ptr_gray run_ctrl_cdc_d2x/out_wr_ptr_gray] \
      [list ffa_ctrl_xcvr_ready run_ctrl_cdc_d2x_out_ready]] {
      lassign $entry name rel
      print_optional_ready "${label} hit_stack_${hs}_${name}" "$inst/$rel"
    }
  }
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
proc observe_rc_fanout {expected_data cycles step} {
  set mask 0
  for {set i 0} {$i < $cycles} {incr i} {
    for {set idx 0} {$idx < 16} {incr idx} {
      set valid_path /tb_feb_to_swb_links/dut/data_path_subsystem/run_control_splitter_out${idx}_valid
      set data_path  /tb_feb_to_swb_links/dut/data_path_subsystem/run_control_splitter_out${idx}_data
      if {[trim_examine $valid_path] eq "1" && [trim_examine $data_path binary] eq $expected_data} {
        set mask [expr {$mask | (1 << $idx)}]
      }
    }
    if {$mask == 65535} {
      break
    }
    run $step
  }
  return $mask
}
proc drive_two_word_frame {data_path valid_path sop_path eop_path word0 word1 step} {
  force -freeze $data_path $word0 0
  force -freeze $sop_path 1 0
  force -freeze $eop_path 0 0
  force -freeze $valid_path 1 0
  run $step

  force -freeze $data_path $word1 0
  force -freeze $sop_path 0 0
  force -freeze $eop_path 1 0
  force -freeze $valid_path 1 0
  run $step

  noforce $data_path
  noforce $sop_path
  noforce $eop_path
  noforce $valid_path
}
set rc_translator_reset_path [first_existing_path [list \
  /tb_feb_to_swb_links/dut/data_path_subsystem/mm_interconnect_1/mm_pipeline_jtagmaster2rstctrl_reset_reset_bridge_in_reset_reset \
  /tb_feb_to_swb_links/dut/data_path_subsystem/mm_interconnect_1/master_datapath_master_translator_reset_reset_bridge_in_reset_reset]]
set rc_master_reset_path [first_existing_path [list \
  /tb_feb_to_swb_links/dut/data_path_subsystem/master_datapath/master_reset_reset \
  /tb_feb_to_swb_links/dut/data_path_subsystem/master_datapath_master_reset_reset]]
set rc_master_clk_reset_path [first_existing_path [list \
  /tb_feb_to_swb_links/dut/data_path_subsystem/mm_interconnect_1/master_datapath_clk_reset_reset_bridge_in_reset_reset \
  /tb_feb_to_swb_links/dut/data_path_subsystem/mm_interconnect_0/master_datapath_clk_reset_reset_bridge_in_reset_reset]]
set rc_lvds_reset_path [first_existing_path [list \
  /tb_feb_to_swb_links/dut/data_path_subsystem/mm_interconnect_1/mm_pipeline_lvds_csr_low_reset_reset_bridge_in_reset_reset \
  /tb_feb_to_swb_links/dut/data_path_subsystem/mm_interconnect_0/mm_pipeline_lvds_csr_low_reset_reset_bridge_in_reset_reset \
  /tb_feb_to_swb_links/dut/data_path_subsystem/mm_interconnect_1/mm_pipeline_lvds_csr_reset_reset_bridge_in_reset_reset \
  /tb_feb_to_swb_links/dut/data_path_subsystem/mm_interconnect_0/mm_pipeline_lvds_csr_reset_reset_bridge_in_reset_reset \
  /tb_feb_to_swb_links/dut/data_path_subsystem/mm_interconnect_1/mm_pipeline_avmm_lvds_reset_reset_bridge_in_reset_reset \
  /tb_feb_to_swb_links/dut/data_path_subsystem/mm_interconnect_0/mm_pipeline_avmm_lvds_reset_reset_bridge_in_reset_reset]]
set rc_mutrig_reset_path [first_existing_path [list \
  /tb_feb_to_swb_links/dut/data_path_subsystem/mm_interconnect_1/mutrig_datapath_subsystem_0_reset_reset_bridge_in_reset_reset \
  /tb_feb_to_swb_links/dut/data_path_subsystem/mm_interconnect_0/mutrig_datapath_subsystem_0_reset_reset_bridge_in_reset_reset]]
set rc_charge_injection_reset_path [first_existing_path [list \
  /tb_feb_to_swb_links/dut/control_path_subsystem/mm_interconnect_0/charge_injection_pulser_0_reset_interface_reset_bridge_in_reset_reset]]
force -freeze $rc_master_reset_path 0 0
force -freeze $rc_master_clk_reset_path 1 0
force -freeze $rc_translator_reset_path 1 0
force -freeze $rc_lvds_reset_path 1 0
force -freeze $rc_mutrig_reset_path 1 0
force -freeze $rc_charge_injection_reset_path 1 0
run 340ns
noforce $rc_master_clk_reset_path
noforce $rc_translator_reset_path
noforce $rc_lvds_reset_path
noforce $rc_mutrig_reset_path
noforce $rc_charge_injection_reset_path
if {![wait_cycles_for_value /tb_feb_to_swb_links/external_injection_window 1 50000 8ns "external injection window"]} {
  quit -code 1 -f
}

print_rc_ready_snapshot "before_probe"
print_hit_stack_cdc_snapshot "before_probe"

set rc_expected_bin 000000100
puts "INFO: probing unforced RC fanout ready under valid"
force -freeze /tb_feb_to_swb_links/dut/upload_subsystem_runctl_mgmt_host_data 2#$rc_expected_bin 0
force -freeze /tb_feb_to_swb_links/dut/upload_subsystem_runctl_mgmt_host_valid 1 0
if {[wait_cycles_for_value /tb_feb_to_swb_links/dut/upload_subsystem_runctl_mgmt_host_ready 1 512 8ns "unforced runctl ready"]} {
  puts "INFO: unforced RC fanout accepted once valid was asserted"
} else {
  puts "ERROR: unforced RC fanout stayed backpressured while valid was asserted"
  print_rc_ready_snapshot "unforced_timeout"
  print_hit_stack_cdc_snapshot "unforced_timeout"
  quit -code 1 -f
}
print_rc_ready_snapshot "unforced_valid"
print_hit_stack_cdc_snapshot "unforced_valid"
noforce /tb_feb_to_swb_links/dut/upload_subsystem_runctl_mgmt_host_valid
noforce /tb_feb_to_swb_links/dut/upload_subsystem_runctl_mgmt_host_data

puts "INFO: driving RC fanout seam into datapath splitter"
force -freeze /tb_feb_to_swb_links/dut/upload_subsystem_runctl_mgmt_host_data 2#$rc_expected_bin 0
force -freeze /tb_feb_to_swb_links/dut/upload_subsystem_runctl_mgmt_host_valid 1 0
set rc_mask [observe_rc_fanout $rc_expected_bin 256 8ns]
noforce /tb_feb_to_swb_links/dut/upload_subsystem_runctl_mgmt_host_valid
noforce /tb_feb_to_swb_links/dut/upload_subsystem_runctl_mgmt_host_data
if {$rc_mask != 65535} {
  puts [format "ERROR: RC fanout incomplete, mask=0x%04X" $rc_mask]
  quit -code 1 -f
}
puts "INFO: RC fanout seam reached all 16 datapath consumers"

set link0_before [sample_nat /tb_feb_to_swb_links/swb_link0_frames]
if {![wait_cycles_for_value /tb_feb_to_swb_links/dut/data_path_subsystem_hit_type3_upper_ready 1 256 8ns "upper upload ready"]} {
  quit -code 1 -f
}
puts "INFO: driving upper FEB frame-assembly seam into upload subsystem"
drive_two_word_frame \
  /tb_feb_to_swb_links/dut/data_path_subsystem_hit_type3_upper_data \
  /tb_feb_to_swb_links/dut/data_path_subsystem_hit_type3_upper_valid \
  /tb_feb_to_swb_links/dut/data_path_subsystem_hit_type3_upper_startofpacket \
  /tb_feb_to_swb_links/dut/data_path_subsystem_hit_type3_upper_endofpacket \
  36'h0A1B2C3D4 36'h051627384 8ns
if {![wait_cycles_for_at_least /tb_feb_to_swb_links/swb_link0_frames [expr {$link0_before + 1}] 512 8ns "upper frame at SWB link0"]} {
  quit -code 1 -f
}
puts "INFO: upper FEB frame reached SWB boundary on link0"

set link1_before [sample_nat /tb_feb_to_swb_links/swb_link1_frames]
if {![wait_cycles_for_value /tb_feb_to_swb_links/upload_data1_ready 1 256 8ns "lower upload ready"]} {
  quit -code 1 -f
}
puts "INFO: driving lower FEB frame-assembly seam toward SWB link1"
drive_two_word_frame \
  /tb_feb_to_swb_links/dut/data_path_subsystem/hit_type3_lower_data \
  /tb_feb_to_swb_links/dut/data_path_subsystem/hit_type3_lower_valid \
  /tb_feb_to_swb_links/dut/data_path_subsystem/hit_type3_lower_startofpacket \
  /tb_feb_to_swb_links/dut/data_path_subsystem/hit_type3_lower_endofpacket \
  36'h0BEEFF111 36'h022334455 8ns
if {![wait_cycles_for_at_least /tb_feb_to_swb_links/swb_link1_frames [expr {$link1_before + 1}] 512 8ns "lower frame at SWB link1"]} {
  quit -code 1 -f
}
puts "INFO: lower FEB frame reached SWB boundary on link1"

run 2us
quit -code 0 -f
EOF

echo "═══ Running FE SciFi v3 RC harness ═══"
run_vsim_logged "${LOG_FILE}" \
  "${VSIM}" -c -do "${VSIM_DO}" \
  -work "${WORK_LIB}" -t ps -voptargs=+acc \
  -suppress 19 -suppress 3009 -suppress 3473 -suppress 12110 -nodpiexports \
  -L altera_ver -L altera_mf_ver -L altera_lnsim_ver -L lpm_ver -L 220model_ver -L twentynm_ver -L sgate_ver \
  tb_feb_to_swb_links
