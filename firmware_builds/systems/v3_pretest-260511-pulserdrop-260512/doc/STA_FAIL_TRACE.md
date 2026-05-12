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
