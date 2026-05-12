# FEB SciFi v3 integration STA fail trace - 2026-05-12

## Scope

Build:
`firmware_builds/systems/v3_pretest-260511-pulserdrop-260512/syn/board_projects/fe_scifi_feb_v3`

Command rerun:

```text
quartus_sta top -c top
```

Trace command:

```text
quartus_sta -t sta/run_4corners_1p0_trace.tcl
```

No refit was run. No `set_false_path` or `set_max_delay` waiver was added.

## Phase A - STA inputs and scale setting

The active board project has no standalone-IP 1.1x clock scale in the loaded
STA inputs.

Active STA wiring:

- `syn/board_projects/fe_scifi_feb_v3/top.qsf:3` loads `top.qip`.
- `syn/board_projects/fe_scifi_feb_v3/top.qip:9` loads `src/top.sdc`.
- `syn/board_projects/fe_scifi_feb_v3/top.qip:30` loads `src/fe/top_FEB_v2.sdc`.
- `syn/board_projects/fe_scifi_feb_v3/src/fe/top_FEB_v2.sdc:22-36` defines nominal 50.000 MHz, 125.000 MHz, and 156.250 MHz base clocks, then runs `derive_pll_clocks -create_base_clocks` and `derive_clock_uncertainty`.

Searches for `1.1x`, `1.10`, scaled periods, `171.875`, `137.5`,
`derive_pll_clocks -scale`, and clock uncertainty overrides found no active
clock scale. The only `1.1` hits in project assignment Tcl are voltage settings
in `assignments/fe_a5_base.tcl:14-19`.

Diff applied for the rerun:

- Added `syn/board_projects/fe_scifi_feb_v3/sta/run_4corners_1p0_trace.tcl`.
- No SDC clock-period edit was required because the active project is already
  at integration 1.0x nominal clocks.

## Phase B - 1.0x four-corner WNS

The nominal `quartus_sta top -c top` rerun completed as a tool phase with
0 errors and 24 warnings. Integration closure still fails.

| Corner | Setup WNS | Hold WNS | Recovery WNS | Removal WNS | Verdict |
| --- | ---: | ---: | ---: | ---: | --- |
| Slow 1100 mV 85 C | -1.245 ns | +0.182 ns | -1.344 ns | +0.457 ns | FAIL |
| Slow 1100 mV 0 C | -1.076 ns | +0.170 ns | -1.243 ns | +0.353 ns | FAIL |
| Fast 1100 mV 85 C | +0.660 ns | +0.075 ns | +1.195 ns | +0.270 ns | PASS |
| Fast 1100 mV 0 C | +0.812 ns | +0.060 ns | +1.296 ns | +0.208 ns | PASS |

Evidence files:

- `syn/board_projects/fe_scifi_feb_v3/quartus_sta_1p0_nominal_20260512.console.log`
- `syn/board_projects/fe_scifi_feb_v3/output_files/top.sta.summary`
- `syn/board_projects/fe_scifi_feb_v3/sta/fail_trace_1p0/summary_1p0.txt`

## Phase C - verdict

FAIL at integration 1.0x nominal clocks.

Setup WNS is negative on both slow corners. Recovery WNS is negative on both
slow corners. Hold WNS is positive on all four corners. No SOF promotion should
be made from this build.

## Worst failing paths

The worst exact slack rows are reset-recovery duplicates into Qsys generated
Avalon-ST clock-crossing buffers. The worst setup family is included because it
is the failing data path that blocks setup closure.

| Rank | Corner/check | Slack | Source pin | Destination pin | Source RTL file:line | Destination RTL file:line | Critical hierarchy |
| ---: | --- | ---: | --- | --- | --- | --- | --- |
| 1 | Slow85 recovery | -1.344 ns | `board_reset_adapter:u_board_reset|board_reset_n_int~DUPLICATE` | `...|mm_interconnect_0|crosser_011|clock_xer|in_data_buffer[76]` | `src/adapters/board_reset_adapter.vhd:23`, deassert assignment at `:48` | `syn/feb_system_v3/synthesis/submodules/altera_avalon_st_clock_crosser.v:57`, async clear at `:78`; instantiated as `crosser_011` in `feb_system_v3_data_path_subsystem_mm_interconnect_0.v:20128` | `board_reset_n_int~DUPLICATE` high-fanout reset route -> `mm_interconnect_0.crosser_011.clock_xer.in_data_buffer[76].clrn` |
| 2 | Slow85 recovery | -1.344 ns | `board_reset_adapter:u_board_reset|board_reset_n_int~DUPLICATE` | `...|mm_interconnect_0|crosser_007|clock_xer|in_data_buffer[38]` | `src/adapters/board_reset_adapter.vhd:23`, deassert assignment at `:48` | `syn/feb_system_v3/synthesis/submodules/altera_avalon_st_clock_crosser.v:57`, async clear at `:78`; instantiated as `crosser_007` in `feb_system_v3_data_path_subsystem_mm_interconnect_0.v:19992` | `board_reset_n_int~DUPLICATE` high-fanout reset route -> `mm_interconnect_0.crosser_007.clock_xer.in_data_buffer[38].clrn` |
| 3 | Slow85 setup | -1.245 ns | `...|altera_avalon_mm_clock_crossing_bridge:mm_clock_crossing_bridge|old_read` | `...|altera_avalon_mm_clock_crossing_bridge:mm_clock_crossing_bridge|pending_read_count[8]` | `syn/feb_system_v3/synthesis/submodules/altera_avalon_mm_clock_crossing_bridge.v:106`, assignment at `:231` | `syn/feb_system_v3/synthesis/submodules/altera_avalon_mm_clock_crossing_bridge.v:100`, counter update at `:206-215`; bridge instance in `feb_system_v3_data_path_subsystem.vhd:4990` | `mm_clock_crossing_bridge.old_read` -> `mm_interconnect_0.mm_clock_crossing_bridge_m0_translator.internal_beginbursttransfer~0` -> `uav_address[14]~9` -> `router.Equal2~2` -> `router.src_channel[25]~6` -> `router.src_data[101]~36/~18` -> `mm_clock_crossing_bridge_m0_limiter.suppress_change_dest_id~1` -> `mm_clock_crossing_bridge.m0_read_accepted` -> `Add0` carry chain -> `pending_read_count[8]` |

Representative verbatim STA rows:

```text
; -1.344 ; board_reset_adapter:u_board_reset|board_reset_n_int~DUPLICATE ; feb_system:u_feb_system|feb_system_v3:u_qsys|feb_system_v3_data_path_subsystem:data_path_subsystem|feb_system_v3_data_path_subsystem_mm_interconnect_0:mm_interconnect_0|altera_avalon_st_handshake_clock_crosser:crosser_011|altera_avalon_st_clock_crosser:clock_xer|in_data_buffer[76] ; spare_clk_osc ; lvds_firefly_clk ; 4.000 ; -0.248 ; 5.046 ;
; -1.344 ; board_reset_adapter:u_board_reset|board_reset_n_int~DUPLICATE ; feb_system:u_feb_system|feb_system_v3:u_qsys|feb_system_v3_data_path_subsystem:data_path_subsystem|feb_system_v3_data_path_subsystem_mm_interconnect_0:mm_interconnect_0|altera_avalon_st_handshake_clock_crosser:crosser_007|altera_avalon_st_clock_crosser:clock_xer|in_data_buffer[38] ; spare_clk_osc ; lvds_firefly_clk ; 4.000 ; -0.249 ; 5.045 ;
; -1.245 ; feb_system:u_feb_system|feb_system_v3:u_qsys|feb_system_v3_data_path_subsystem:data_path_subsystem|altera_avalon_mm_clock_crossing_bridge:mm_clock_crossing_bridge|old_read ; feb_system:u_feb_system|feb_system_v3:u_qsys|feb_system_v3_data_path_subsystem:data_path_subsystem|altera_avalon_mm_clock_crossing_bridge:mm_clock_crossing_bridge|pending_read_count[8] ; u_feb_system|u_qsys|data_path_subsystem|lvds_rx_28nm_0|ALTLVDS_RX_component|auto_generated|pll_sclk~PLL_OUTPUT_COUNTER|divclk ; u_feb_system|u_qsys|data_path_subsystem|lvds_rx_28nm_0|ALTLVDS_RX_component|auto_generated|pll_sclk~PLL_OUTPUT_COUNTER|divclk ; 8.000 ; -0.109 ; 9.086 ;
```

The top Slow0 recovery row is the same source/destination class at -1.243 ns:

```text
; -1.243 ; board_reset_adapter:u_board_reset|board_reset_n_int~DUPLICATE ; feb_system:u_feb_system|feb_system_v3:u_qsys|feb_system_v3_data_path_subsystem:data_path_subsystem|feb_system_v3_data_path_subsystem_mm_interconnect_0:mm_interconnect_0|altera_avalon_st_handshake_clock_crosser:crosser_011|altera_avalon_st_clock_crosser:clock_xer|in_data_buffer[76] ; spare_clk_osc ; lvds_firefly_clk ; 4.000 ; -0.223 ; 4.970 ;
```

## Root-cause hypotheses

### Recovery failure

The recovery failures are dominated by routing on a high-fanout board reset
deassertion path from `board_reset_n_int` in the `spare_clk_osc` domain into
async-clear pins of Qsys Avalon-ST handshake clock-crossing buffers in the
`lvds_firefly_clk` domain. The Slow85 path reports 1 logic level, 5.046 ns data
delay, and 84 percent of data delay in routing.

This looks like reset-tree/reset-CDC integration debt exposed by current
placement, not a data-path CDC introduced by the pulser-drop change. The right
fix is to audit how `board_reset_n_int` is converted into each Qsys reset
domain and either localize/synchronize reset deassertion through generated reset
controllers or regenerate Qsys with the corrected reset topology. A blanket
waiver was not added.

### Setup failure

The setup failure is inside generated Intel Avalon-MM clock-crossing bridge and
Merlin interconnect flow control. The path feeds `pending_read_count[8]` through
read-accept/space-available logic, router address decode, limiter logic, and a
carry chain in the bridge. The Slow85 path reports 9 logic levels and 9.086 ns
data delay against an 8.000 ns relationship, with 63 percent of data delay in
routing.

This is likely a post-pulser-drop placement/routing shift or Qsys interconnect
topology/version regression around `mm_clock_crossing_bridge_m0`, not an
intentional new CDC. Candidate fixes are Qsys-level structural changes such as
an added pipeline/bridge boundary or regenerating with an interconnect option
that cuts the long Merlin feedback cone. No timing exception should be applied
without a functional proof.

## 2026-05-12 reset-sync partial closure

Command rerun after Qsys reset synchronization:

```text
quartus_sh --flow compile top -c top
quartus_sta top -c top
quartus_sta -t sta/run_4corners_1p0_trace.tcl
```

The generated Qsys reset topology now contains:

- parent `mclk125_reset_sync` (`altera_reset_controller`, `SYNC_DEPTH=2`) for `upload_subsystem.upload_sc_clock_reset`
- child `monitor_reset_sync` (`altera_reset_controller`, `SYNC_DEPTH=2`) for `master_datapath.clk_reset`, `lvds_rx_controller_pro_0.{control,data}_reset`, `mutrig_reset_controller_0.dpa_reset`, `mm_clock_crossing_bridge.m0_reset`, and `mm_pipeline_jtagmaster2rstctrl.reset`

The raw board reset now feeds the child synchronizer input only:

```text
monitor_reset_in_reset_reset_n_ports_inv -> monitor_reset_sync.reset_in0
monitor_reset_sync_reset_out_reset -> mm_pipeline_jtagmaster2rstctrl_reset_reset_bridge_in_reset_reset
```

No `set_false_path`, `set_max_delay`, or synchronized-side timing exception was added.

### New 1.0x four-corner WNS

| Corner | Setup WNS | Hold WNS | Recovery WNS | Removal WNS | Verdict |
| --- | ---: | ---: | ---: | ---: | --- |
| Slow 1100 mV 85 C | -3.220 ns | +0.187 ns | +1.628 ns | +0.375 ns | FAIL |
| Slow 1100 mV 0 C | -3.074 ns | +0.170 ns | +1.832 ns | +0.361 ns | FAIL |
| Fast 1100 mV 85 C | -1.764 ns | +0.077 ns | +3.456 ns | +0.274 ns | FAIL |
| Fast 1100 mV 0 C | -1.647 ns | +0.062 ns | +3.819 ns | +0.211 ns | FAIL |

Recovery is closed on all four corners. The old Slow85 recovery failure from
`board_reset_adapter.u_board_reset.board_reset_n_int~DUPLICATE` into
`mm_interconnect_0.crosser_011/crosser_007.clock_xer.in_data_buffer[*]`
is no longer present in the top recovery reports.

### New worst setup paths

| Corner | Rank | Slack | Source | Destination | Launch clock | Latch clock |
| --- | ---: | ---: | --- | --- | --- | --- |
| Slow85 | 1 | -3.220 ns | `runctl_mgmt_host_0.snap_exec_ts_lvds[9]` | `runctl_mgmt_host_0.snap_exec_ts_mm_q0[9]` | `pll_sclk~PLL_OUTPUT_COUNTER|divclk` | `transceiver_pll_clock[0]` |
| Slow85 | 2 | -2.922 ns | `runctl_mgmt_host_0.snap_run_number_lvds[2]` | `runctl_mgmt_host_0.snap_run_number_mm_q0[2]` | `pll_sclk~PLL_OUTPUT_COUNTER|divclk` | `transceiver_pll_clock[0]` |
| Slow85 | 3 | -2.899 ns | `runctl_mgmt_host_0.snap_run_number_lvds[3]` | `runctl_mgmt_host_0.snap_run_number_mm_q0[3]` | `pll_sclk~PLL_OUTPUT_COUNTER|divclk` | `transceiver_pll_clock[0]` |
| Slow0 | 1 | -3.074 ns | `runctl_mgmt_host_0.snap_exec_ts_lvds[9]` | `runctl_mgmt_host_0.snap_exec_ts_mm_q0[9]` | `pll_sclk~PLL_OUTPUT_COUNTER|divclk` | `transceiver_pll_clock[0]` |
| Slow0 | 2 | -2.771 ns | `runctl_mgmt_host_0.snap_exec_ts_lvds[14]` | `runctl_mgmt_host_0.snap_exec_ts_mm_q0[14]` | `pll_sclk~PLL_OUTPUT_COUNTER|divclk` | `transceiver_pll_clock[0]` |
| Slow0 | 3 | -2.763 ns | `runctl_mgmt_host_0.snap_run_number_lvds[3]` | `runctl_mgmt_host_0.snap_run_number_mm_q0[3]` | `pll_sclk~PLL_OUTPUT_COUNTER|divclk` | `transceiver_pll_clock[0]` |
| Fast85 | 1 | -1.764 ns | `runctl_mgmt_host_0.snap_exec_ts_lvds[9]` | `runctl_mgmt_host_0.snap_exec_ts_mm_q0[9]` | `pll_sclk~PLL_OUTPUT_COUNTER|divclk` | `transceiver_pll_clock[0]` |
| Fast85 | 2 | -1.534 ns | `runctl_mgmt_host_0.snap_run_number_lvds[3]` | `runctl_mgmt_host_0.snap_run_number_mm_q0[3]` | `pll_sclk~PLL_OUTPUT_COUNTER|divclk` | `transceiver_pll_clock[0]` |
| Fast85 | 3 | -1.525 ns | `runctl_mgmt_host_0.snap_exec_ts_lvds[32]` | `runctl_mgmt_host_0.snap_exec_ts_mm_q0[32]` | `pll_sclk~PLL_OUTPUT_COUNTER|divclk` | `transceiver_pll_clock[0]` |
| Fast0 | 1 | -1.647 ns | `runctl_mgmt_host_0.snap_exec_ts_lvds[9]` | `runctl_mgmt_host_0.snap_exec_ts_mm_q0[9]` | `pll_sclk~PLL_OUTPUT_COUNTER|divclk` | `transceiver_pll_clock[0]` |
| Fast0 | 2 | -1.446 ns | `runctl_mgmt_host_0.snap_run_number_lvds[3]` | `runctl_mgmt_host_0.snap_run_number_mm_q0[3]` | `pll_sclk~PLL_OUTPUT_COUNTER|divclk` | `transceiver_pll_clock[0]` |
| Fast0 | 3 | -1.433 ns | `runctl_mgmt_host_0.snap_run_number_lvds[2]` | `runctl_mgmt_host_0.snap_run_number_mm_q0[2]` | `pll_sclk~PLL_OUTPUT_COUNTER|divclk` | `transceiver_pll_clock[0]` |

The remaining failures are setup-only paths in `upload_subsystem.runctl_mgmt_host_0`
snapshot synchronization from the LVDS clock domain to `transceiver_pll_clock[0]`.
They are not the original Qsys Avalon-ST reset-recovery crosser paths.

Evidence files:

- `syn/feb_system_v3_qsys_generate_20260512_2318_reset_sync_metadata_isolated.status`
- `syn/board_projects/fe_scifi_feb_v3/quartus_compile_reset_sync_20260512.console.log`
- `syn/board_projects/fe_scifi_feb_v3/quartus_sta_reset_sync_20260512.console.log`
- `syn/board_projects/fe_scifi_feb_v3/quartus_sta_1p0_trace_reset_sync_20260512.console.log`
- `syn/board_projects/fe_scifi_feb_v3/sta/fail_trace_1p0/summary_1p0.txt`
- `syn/board_projects/fe_scifi_feb_v3/sta/fail_trace_1p0/*_{setup,hold,recovery,removal}_full_path.rpt`

SOF produced by the partial-closure compile:

```text
65ec83118934df80f7485b2e85bec7813e7c6a0d12fe8bc8c76ae310f01123b0  output_files/top.sof
```

Verdict: `partial-closure`. Reset recovery is fixed; integration 1.0x still
fails setup, so no further timing fix was attempted in this run.

## 2026-05-12 post-reset-sync setup trace (per-IP)

Scope: trace-only analysis of the already-generated
`sta/fail_trace_1p0/*_setup_full_path.rpt` reports. No RTL, Qsys, SDC, fitter,
or STA rerun was performed for this section.

Legend: `RCMH` = `run-control_mgmt/runctl_mgmt_host`, Qsys instance
`runctl_mgmt_host_0`; full register hierarchy prefix is:

```text
feb_system:u_feb_system|feb_system_v3:u_qsys|feb_system_v3_upload_subsystem:upload_subsystem|runctl_mgmt_host:runctl_mgmt_host_0
```

Clock aliases used below:

- `LVDS_PLL` =
  `u_feb_system|u_qsys|data_path_subsystem|lvds_rx_28nm_0|ALTLVDS_RX_component|auto_generated|pll_sclk~PLL_OUTPUT_COUNTER|divclk`
- `XCVR_PLL` = `transceiver_pll_clock[0]`

### Phase A - worst 10 setup paths per failing corner

#### Slow85

| Rank | Slack | Source pin | Destination pin | Source clock | Destination clock | Owner | Source register hierarchy | Destination register hierarchy |
| ---: | ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | -3.220 ns | `snap_exec_ts_lvds[9]` | `snap_exec_ts_mm_q0[9]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_exec_ts_lvds[9]` | `RCMH|snap_exec_ts_mm_q0[9]` |
| 2 | -2.922 ns | `snap_run_number_lvds[2]` | `snap_run_number_mm_q0[2]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_run_number_lvds[2]` | `RCMH|snap_run_number_mm_q0[2]` |
| 3 | -2.899 ns | `snap_run_number_lvds[3]` | `snap_run_number_mm_q0[3]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_run_number_lvds[3]` | `RCMH|snap_run_number_mm_q0[3]` |
| 4 | -2.898 ns | `host_state_lvds[0]` | `host_state_sync_attr_q0[0]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|host_state_lvds[0]` | `RCMH|host_state_sync_attr_q0[0]` |
| 5 | -2.893 ns | `snap_exec_ts_lvds[14]` | `snap_exec_ts_mm_q0[14]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_exec_ts_lvds[14]` | `RCMH|snap_exec_ts_mm_q0[14]` |
| 6 | -2.892 ns | `snap_run_number_lvds[10]` | `snap_run_number_mm_q0[10]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_run_number_lvds[10]` | `RCMH|snap_run_number_mm_q0[10]` |
| 7 | -2.883 ns | `snap_recv_ts_lvds[35]` | `snap_recv_ts_mm_q0[35]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_recv_ts_lvds[35]` | `RCMH|snap_recv_ts_mm_q0[35]` |
| 8 | -2.879 ns | `snap_run_number_lvds[19]` | `snap_run_number_mm_q0[19]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_run_number_lvds[19]` | `RCMH|snap_run_number_mm_q0[19]` |
| 9 | -2.857 ns | `snap_run_number_lvds[27]` | `snap_run_number_mm_q0[27]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_run_number_lvds[27]` | `RCMH|snap_run_number_mm_q0[27]` |
| 10 | -2.856 ns | `snap_run_number_lvds[13]` | `snap_run_number_mm_q0[13]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_run_number_lvds[13]` | `RCMH|snap_run_number_mm_q0[13]` |

#### Slow0

| Rank | Slack | Source pin | Destination pin | Source clock | Destination clock | Owner | Source register hierarchy | Destination register hierarchy |
| ---: | ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | -3.074 ns | `snap_exec_ts_lvds[9]` | `snap_exec_ts_mm_q0[9]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_exec_ts_lvds[9]` | `RCMH|snap_exec_ts_mm_q0[9]` |
| 2 | -2.771 ns | `snap_exec_ts_lvds[14]` | `snap_exec_ts_mm_q0[14]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_exec_ts_lvds[14]` | `RCMH|snap_exec_ts_mm_q0[14]` |
| 3 | -2.763 ns | `snap_run_number_lvds[3]` | `snap_run_number_mm_q0[3]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_run_number_lvds[3]` | `RCMH|snap_run_number_mm_q0[3]` |
| 4 | -2.762 ns | `snap_run_number_lvds[2]` | `snap_run_number_mm_q0[2]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_run_number_lvds[2]` | `RCMH|snap_run_number_mm_q0[2]` |
| 5 | -2.758 ns | `host_state_lvds[0]` | `host_state_sync_attr_q0[0]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|host_state_lvds[0]` | `RCMH|host_state_sync_attr_q0[0]` |
| 6 | -2.718 ns | `snap_run_number_lvds[10]` | `snap_run_number_mm_q0[10]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_run_number_lvds[10]` | `RCMH|snap_run_number_mm_q0[10]` |
| 7 | -2.714 ns | `snap_run_number_lvds[19]` | `snap_run_number_mm_q0[19]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_run_number_lvds[19]` | `RCMH|snap_run_number_mm_q0[19]` |
| 8 | -2.712 ns | `snap_recv_ts_lvds[35]` | `snap_recv_ts_mm_q0[35]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_recv_ts_lvds[35]` | `RCMH|snap_recv_ts_mm_q0[35]` |
| 9 | -2.702 ns | `snap_recv_ts_lvds[18]` | `snap_recv_ts_mm_q0[18]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_recv_ts_lvds[18]` | `RCMH|snap_recv_ts_mm_q0[18]` |
| 10 | -2.700 ns | `snap_exec_ts_lvds[32]` | `snap_exec_ts_mm_q0[32]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_exec_ts_lvds[32]` | `RCMH|snap_exec_ts_mm_q0[32]` |

#### Fast85

| Rank | Slack | Source pin | Destination pin | Source clock | Destination clock | Owner | Source register hierarchy | Destination register hierarchy |
| ---: | ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | -1.764 ns | `snap_exec_ts_lvds[9]` | `snap_exec_ts_mm_q0[9]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_exec_ts_lvds[9]` | `RCMH|snap_exec_ts_mm_q0[9]` |
| 2 | -1.534 ns | `snap_run_number_lvds[3]` | `snap_run_number_mm_q0[3]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_run_number_lvds[3]` | `RCMH|snap_run_number_mm_q0[3]` |
| 3 | -1.525 ns | `snap_exec_ts_lvds[32]` | `snap_exec_ts_mm_q0[32]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_exec_ts_lvds[32]` | `RCMH|snap_exec_ts_mm_q0[32]` |
| 4 | -1.515 ns | `snap_run_number_lvds[2]` | `snap_run_number_mm_q0[2]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_run_number_lvds[2]` | `RCMH|snap_run_number_mm_q0[2]` |
| 5 | -1.513 ns | `snap_recv_ts_lvds[18]` | `snap_recv_ts_mm_q0[18]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_recv_ts_lvds[18]` | `RCMH|snap_recv_ts_mm_q0[18]` |
| 6 | -1.510 ns | `host_state_lvds[0]` | `host_state_sync_attr_q0[0]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|host_state_lvds[0]` | `RCMH|host_state_sync_attr_q0[0]` |
| 7 | -1.502 ns | `snap_exec_ts_lvds[22]` | `snap_exec_ts_mm_q0[22]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_exec_ts_lvds[22]` | `RCMH|snap_exec_ts_mm_q0[22]` |
| 8 | -1.501 ns | `snap_recv_ts_lvds[45]` | `snap_recv_ts_mm_q0[45]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_recv_ts_lvds[45]` | `RCMH|snap_recv_ts_mm_q0[45]` |
| 9 | -1.501 ns | `snap_recv_ts_lvds[40]` | `snap_recv_ts_mm_q0[40]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_recv_ts_lvds[40]` | `RCMH|snap_recv_ts_mm_q0[40]` |
| 10 | -1.498 ns | `snap_exec_ts_lvds[8]` | `snap_exec_ts_mm_q0[8]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_exec_ts_lvds[8]` | `RCMH|snap_exec_ts_mm_q0[8]` |

#### Fast0

| Rank | Slack | Source pin | Destination pin | Source clock | Destination clock | Owner | Source register hierarchy | Destination register hierarchy |
| ---: | ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | -1.647 ns | `snap_exec_ts_lvds[9]` | `snap_exec_ts_mm_q0[9]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_exec_ts_lvds[9]` | `RCMH|snap_exec_ts_mm_q0[9]` |
| 2 | -1.446 ns | `snap_run_number_lvds[3]` | `snap_run_number_mm_q0[3]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_run_number_lvds[3]` | `RCMH|snap_run_number_mm_q0[3]` |
| 3 | -1.433 ns | `snap_run_number_lvds[2]` | `snap_run_number_mm_q0[2]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_run_number_lvds[2]` | `RCMH|snap_run_number_mm_q0[2]` |
| 4 | -1.430 ns | `host_state_lvds[0]` | `host_state_sync_attr_q0[0]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|host_state_lvds[0]` | `RCMH|host_state_sync_attr_q0[0]` |
| 5 | -1.427 ns | `snap_exec_ts_lvds[32]` | `snap_exec_ts_mm_q0[32]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_exec_ts_lvds[32]` | `RCMH|snap_exec_ts_mm_q0[32]` |
| 6 | -1.425 ns | `snap_recv_ts_lvds[18]` | `snap_recv_ts_mm_q0[18]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_recv_ts_lvds[18]` | `RCMH|snap_recv_ts_mm_q0[18]` |
| 7 | -1.410 ns | `snap_recv_ts_lvds[45]` | `snap_recv_ts_mm_q0[45]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_recv_ts_lvds[45]` | `RCMH|snap_recv_ts_mm_q0[45]` |
| 8 | -1.408 ns | `snap_recv_ts_lvds[40]` | `snap_recv_ts_mm_q0[40]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_recv_ts_lvds[40]` | `RCMH|snap_recv_ts_mm_q0[40]` |
| 9 | -1.408 ns | `snap_exec_ts_lvds[22]` | `snap_exec_ts_mm_q0[22]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_exec_ts_lvds[22]` | `RCMH|snap_exec_ts_mm_q0[22]` |
| 10 | -1.407 ns | `snap_run_number_lvds[19]` | `snap_run_number_mm_q0[19]` | `LVDS_PLL` | `XCVR_PLL` | `RCMH -> RCMH` | `RCMH|snap_run_number_lvds[19]` | `RCMH|snap_run_number_mm_q0[19]` |

### Phase B - per-IP roll-up

| IP | Failing path count | Worst slack | Source clock | Dest clock | Sample path hierarchy |
| --- | ---: | ---: | --- | --- | --- |
| `run-control_mgmt/runctl_mgmt_host` | 40 | -3.220 ns | `LVDS_PLL` | `XCVR_PLL` | `RCMH|snap_exec_ts_lvds[9]` -> `RCMH|snap_exec_ts_mm_q0[9]` |

All worst-10 setup endpoints across the four corners resolve to the same
owning IP. The owner mapping comes from Qsys component kind
`runctl_mgmt_host` and the component file set that sets `runctl_mgmt_host.sv`
as the top-level source.

Endpoint-family distribution within `runctl_mgmt_host`:

| Destination register family | Count | Worst slack | Representative source -> destination |
| --- | ---: | ---: | --- |
| `snap_run_number_mm_q0` | 15 | -2.922 ns | `snap_run_number_lvds[2]` -> `snap_run_number_mm_q0[2]` |
| `snap_exec_ts_mm_q0` | 12 | -3.220 ns | `snap_exec_ts_lvds[9]` -> `snap_exec_ts_mm_q0[9]` |
| `snap_recv_ts_mm_q0` | 9 | -2.883 ns | `snap_recv_ts_lvds[35]` -> `snap_recv_ts_mm_q0[35]` |
| `host_state_sync_attr_q0` | 4 | -2.898 ns | `host_state_lvds[0]` -> `host_state_sync_attr_q0[0]` |

### Phase C - representative RTL locations and logic depth

The top IP cluster has no LUT cone between the launch and capture registers:
TimeQuest reports `Number of Logic Levels = 0` for each representative. The
negative slack is therefore dominated by CDC timing treatment, clock skew, and
direct FF-to-FF routing/cell delay rather than deep combinational logic.

| Cluster | Representative path | Slack | Logic depth | Data delay | Data route share | Source declaration | Destination declaration |
| --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| snap_exec_ts snapshot CDC | `snap_exec_ts_lvds[9]` -> `snap_exec_ts_mm_q0[9]` | -3.220 ns | 0 LUT levels | 1.431 ns | 63% (0.907 ns) | `run-control_mgmt/rtl/runctl_mgmt_host.sv:862` | `run-control_mgmt/rtl/runctl_mgmt_host.sv:901` |
| snap_run_number snapshot CDC | `snap_run_number_lvds[2]` -> `snap_run_number_mm_q0[2]` | -2.922 ns | 0 LUT levels | 1.162 ns | 54% (0.630 ns) | `run-control_mgmt/rtl/runctl_mgmt_host.sv:857` | `run-control_mgmt/rtl/runctl_mgmt_host.sv:895` |
| snap_recv_ts snapshot CDC | `snap_recv_ts_lvds[35]` -> `snap_recv_ts_mm_q0[35]` | -2.883 ns | 0 LUT levels | 1.097 ns | 52% (0.569 ns) | `run-control_mgmt/rtl/runctl_mgmt_host.sv:861` | `run-control_mgmt/rtl/runctl_mgmt_host.sv:900` |
| host_state status CDC | `host_state_lvds[0]` -> `host_state_sync_attr_q0[0]` | -2.898 ns | 0 LUT levels | 1.147 ns | 54% (0.615 ns) | `run-control_mgmt/rtl/runctl_mgmt_host.sv:175` | `run-control_mgmt/rtl/runctl_mgmt_host.sv:1038` |

Source snapshot run-number register:
`run-control_mgmt/rtl/runctl_mgmt_host.sv:857`

```systemverilog
  855     // safe despite multi-bit CDC.
  856     logic [7:0]  snap_last_cmd_lvds;
  857     logic [31:0] snap_run_number_lvds;
  858     logic [15:0] snap_reset_assert_lvds, snap_reset_release_lvds;
  859     logic [15:0] snap_fpga_addr_lvds;
```

Source snapshot timestamp registers:
`run-control_mgmt/rtl/runctl_mgmt_host.sv:861`

```systemverilog
  858     logic [15:0] snap_reset_assert_lvds, snap_reset_release_lvds;
  859     logic [15:0] snap_fpga_addr_lvds;
  860     logic        snap_fpga_addr_valid_lvds;
  861     logic [47:0] snap_recv_ts_lvds;
  862     logic [47:0] snap_exec_ts_lvds;
```

Destination snapshot registers:
`run-control_mgmt/rtl/runctl_mgmt_host.sv:895`

```systemverilog
  893     // mm-side shadow registers
  894     (* async_reg = "true", preserve = "true" *) logic [7:0]  snap_last_cmd_mm_q0, snap_last_cmd_mm_q1;
  895     (* async_reg = "true", preserve = "true" *) logic [31:0] snap_run_number_mm_q0, snap_run_number_mm_q1;
  896     (* async_reg = "true", preserve = "true" *) logic [15:0] snap_reset_assert_mm_q0, snap_reset_assert_mm_q1;
  897     (* async_reg = "true", preserve = "true" *) logic [15:0] snap_reset_release_mm_q0, snap_reset_release_mm_q1;
```

Destination snapshot timestamp registers:
`run-control_mgmt/rtl/runctl_mgmt_host.sv:900`

```systemverilog
  897     (* async_reg = "true", preserve = "true" *) logic [15:0] snap_reset_release_mm_q0, snap_reset_release_mm_q1;
  898     (* async_reg = "true", preserve = "true" *) logic [15:0] snap_fpga_addr_mm_q0, snap_fpga_addr_mm_q1;
  899     (* async_reg = "true", preserve = "true" *) logic        snap_fpga_addr_valid_mm_q0, snap_fpga_addr_valid_mm_q1;
  900     (* async_reg = "true", preserve = "true" *) logic [47:0] snap_recv_ts_mm_q0, snap_recv_ts_mm_q1;
  901     (* async_reg = "true", preserve = "true" *) logic [47:0] snap_exec_ts_mm_q0, snap_exec_ts_mm_q1;
```

Source status register:
`run-control_mgmt/rtl/runctl_mgmt_host.sv:175`

```systemverilog
  172     // ============================================================
  173     // lvds domain status -> mm (individual-bit 2FF)
  174     logic        recv_idle_lvds, host_idle_lvds;
  175     logic [7:0]  recv_state_lvds, host_state_lvds;
  176     logic        dp_hard_reset_raw, ct_hard_reset_raw;
```

Destination status synchronizer:
`run-control_mgmt/rtl/runctl_mgmt_host.sv:1038`

```systemverilog
 1036     (* async_reg = "true", preserve = "true" *) logic [1:0] dp_hreset_sync_attr, ct_hreset_sync_attr;
 1037     (* async_reg = "true", preserve = "true" *) logic [15:0] recv_state_sync_attr_q0, recv_state_sync_attr_q1;
 1038     (* async_reg = "true", preserve = "true" *) logic [15:0] host_state_sync_attr_q0, host_state_sync_attr_q1;
 1039
 1040     always_ff @(posedge mm_clk) begin
```

### Phase D - per-cluster hypotheses

`run-control_mgmt/runctl_mgmt_host` is the only IP owner in the worst-10 setup
population. The reported data path has 0 LUT levels, so the slow stage is not
a deep combinational cone inside the command decoder or CSR readback path; it
is a direct multi-bit LVDS-domain register to first MM-domain shadow register
transfer. Slow85 path #1 has 1.431 ns data delay with 63% in data routing, but
the larger timing loss is the -2.139 ns cross-clock skew against a 0.400 ns
setup relationship. This is plausibly an inherent CDC/constraint problem in
the IP that the reset-sync placement shift exposed by moving the surrounding
placement, not a Qsys auto-inserted adapter path, because both endpoints sit
under `runctl_mgmt_host_0` and no Merlin/adapter hierarchy appears between
them.

The `snap_run_number`, `snap_exec_ts`, and `snap_recv_ts` endpoint families are
CSR snapshot CDC registers. They are tagged `async_reg` on the MM side, but
the source-side multi-bit snapshot bus is still timed directly into the first
MM shadow stage in these reports. A patch should retime the snapshot transfer
as a handshake-qualified bundle or constrain/structure the CDC so only the
toggle synchronizer is timed, with the multi-bit payload captured after
stability is proven. Register duplication may help placement, but it is
secondary to making the CDC contract explicit.

The `host_state_lvds` to `host_state_sync_attr_q0` family is a status CDC path,
not the CSR snapshot bundle, but it has the same direct FF-to-FF shape: 0 LUT
levels, 1.147 ns Slow85 data delay, and 54% data routing. This looks like
individual-bit 2FF status synchronization that became timing-visible under the
current cross-clock relationship. The likely patch is to preserve a proper
single-bit/toggle synchronizer shape for status bits and audit the SDC/IP
packaging so the first synchronizer stage is treated as an asynchronous capture
point rather than a normal setup endpoint.

No top-10 path points at a Qsys auto-inserted Avalon adapter. Qsys may have
changed placement pressure when reset controllers were inserted, but the
failing register owner remains the hand-written `runctl_mgmt_host` IP. If a
Qsys-level mitigation is desired after the IP CDC is fixed, the useful
structural lever is an `altera_avalon_mm_bridge` or similar pipeline boundary
around CSR readback traffic; it would not directly cut the current LVDS-to-MM
snapshot first-stage paths.

### Recommended next action

- `run-control_mgmt/runctl_mgmt_host`: retime the CSR snapshot CDC so
  `snap_*_lvds` payload bits are captured in `mm_clk` only after a synchronized
  update/valid handshake proves stability; audit or add the corresponding CDC
  constraint around the first `*_mm_q0` stages.
- `run-control_mgmt/runctl_mgmt_host` status CDC: review `host_state_lvds` /
  `*_sync_attr_q0` synchronizer constraints and attributes so the first
  MM-stage status synchronizer is not optimized or timed as ordinary
  synchronous logic.
- Qsys integration: do not patch Qsys first for these top failures; reserve an
  `altera_avalon_mm_bridge` or CSR pipeline boundary for any remaining CSR
  readback timing after the IP-local CDC paths are corrected.
