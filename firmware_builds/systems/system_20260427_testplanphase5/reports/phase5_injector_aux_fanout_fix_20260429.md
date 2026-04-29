# Phase 5 Injector Aux-Fanout Fix Report

- Date: `2026-04-29`
- Scope: `pulse_fanout8`, `scifi_datapath_system_v3_pipe`, `feb_system_v3_pipe`, injector micro SignalTap
- Status: `BOARD_EMU_PASS_REAL_BLOCKED`

## Root Cause

The live micro SignalTap fallback capture showed the active injector pulse was
low while `pulse_fanout8` output lane 0 and `emulator_mutrig_0.coe_inject_pulse`
sampled high at time zero. Source inspection matched the capture:

- `pulse_fanout8` ORed `coe_inject_pulse | coe_aux_inject_pulse`.
- `scifi_datapath_system_v3_pipe.qsys` exported `inject_aux`.
- the parent generated FEB wrapper left the data-path `inject_aux_pulse` open.

That open deprecated auxiliary/charge-injection conduit could force the fanout
high and prevent a rising-edge trigger or a real injector edge from reaching
the emulator as a clean transition.

## Fix

- Removed the deprecated auxiliary input from `misc/pulse_fanout8/pulse_fanout8.sv`.
- Removed `inject_aux_in` from `misc/pulse_fanout8/pulse_fanout8_hw.tcl` and bumped the package to `26.2.0.0429`.
- Removed exported `inject_aux` interfaces from `scifi_datapath_system_v3.qsys`, `scifi_datapath_system_v3_lat4.qsys`, and `scifi_datapath_system_v3_pipe.qsys`.
- Regenerated `scifi_datapath_system_v3_pipe` and `feb_system_v3_pipe`; no generated synthesis wrapper or SOPC info now contains `inject_aux` or `coe_aux_inject_pulse`.
- Removed the aux probe from `generate_phase5_injector_path_stp.py`.

## Additional Finding: Injector CSR Waitrequest

The no-aux idle SignalTap rerun with a clean STP confirmed that the fanout no
longer powers up high, but it also exposed a separate control-path hazard:
`mutrig_injector_0.avs_csr_waitrequest` was sampled high while no CSR read or
write was active. The direct JTAG Avalon master then timed out on the first
injector multiword write to byte address `0x0002B200`, matching a permanently
stalled CSR slave rather than a datapath pulse failure.

The injector source has been patched to keep `avs_csr_waitrequest` deasserted
at reset and idle. The package version is now `26.0.2.0429`, and the regenerated
active VHDL/QIP path is free of `inject_aux`, `coe_aux_inject_pulse`, and
`charge_inj_pulser` references.

## Verification

| Check | Result | Evidence |
|---|---|---|
| RTL style | `PASS` | `rtl_style_check.py misc/pulse_fanout8/pulse_fanout8.sv` |
| `_hw.tcl` vs HDL ports | `PASS` | `pd_hw_tcl_lint.py misc/pulse_fanout8/pulse_fanout8_hw.tcl --hdl misc/pulse_fanout8/pulse_fanout8.sv` |
| Datapath Qsys regenerate | `PASS` | `syn/qsys_generate_scifi_datapath_system_v3_pipe_noaux_v2_20260429.log` |
| Parent FEB Qsys regenerate | `PASS` | `syn/qsys_generate_feb_system_v3_pipe_noaux_20260429.log` |
| Injector waitrequest fix Qsys regenerate | `PASS` | `syn/qsys_generate_scifi_datapath_system_v3_pipe_injector_waitrequest_fix_20260429.log`, `syn/qsys_generate_feb_system_v3_pipe_injector_waitrequest_fix_20260429.log` |
| Authentic injector integration sim | `PASS` | `tb/INT_fe_scifi_v3-2026-04-17/REPORT/dp_injector_authentic/run_dp_injector_authentic.log` |
| Injector micro STP regenerate/import | `PASS` | `signaltap/phase5_injector_path_lvds_micro_prepare_noaux_20260429.log`, `signaltap/phase5_injector_path_lvds.nodes.md` |
| Clean no-aux idle SignalTap capture | `PASS` | `captures/phase5_injector_mode0_low_noaux_cleanstp_20260429.vcd`, `reports/phase5_injector_mode0_low_noaux_cleanstp_capture_20260429.log` |
| Direct JTAG injector CSR setup before waitrequest fix | `FAIL` | `reports/phase5_injector_jtag_preset_setup_injector_only_noaux_xvfb_20260429.log` |
| Guarded host SC injector read before waitrequest fix | `FAIL` | `reports/phase5_injector_host_single_read_mode_noaux_20260429.log` |
| Waitrequest-fix compile / STA | `PASS` | `syn/board_projects/fe_scifi_feb_v3/quartus_compile_top_stp_pipe_phase5_injector_waitrequest_fix_20260429.console.log`, `output_files_pipe_phase5_injector_stp/top_stp_pipe_phase5_injector.sta.summary` |
| Waitrequest-fix SOF programming | `PASS` | `syn/board_projects/fe_scifi_feb_v3/program_top_stp_pipe_phase5_injector_waitrequest_fix_20260429.log` |
| Generated SC bridge address audit after SWB reload | `PASS` | `reports/phase5_full_svd_address_map_20260429.json`, `reports/phase5_debug_sc_svd_inventory_20260429.json` |
| Live SC emulator injector lane-0 | `PASS` | `reports/phase5_injector_emulator_lane0_sc_recovered_20260429.md`, `reports/phase5_injector_emulator_lane0_rate_sweep_sc_recovered_20260429.md` |
| Injector-off and lane-mask negative controls | `PASS_AS_NEGATIVE_CONTROL` | `reports/phase5_injector_emulator_lane0_off_baseline_sc_recovered_20260429.md`, `reports/phase5_injector_emulator_mask0_sc_recovered_20260429.md` |
| Pre-armed injector SignalTap pulse proof | `PASS` | `reports/phase5_injector_prearmed_stp_20260429.md`, `captures/phase5_injector_path_prearmed_periodic_20260429.vcd` |
| Real MuTRiG XML config attempt, ASIC 0 | `FAIL_LOCK` | `reports/phase5_mutrig_config_asic0_20260429.md` |

The 2026-04-29 waitrequest-fix authentic sim preserved the expected closure
counts:
`top_pulse=110`, `qsys_pulse=110`, `fanout=110`, `emu_pin=110`,
`hit_wr=20` per lane, 160 accepted type0 transfers, 160 MTS type1 outputs,
160 pre-RBCAM rate-hist hits, 160 latency-hist hits, and zero histogram
drops/underflows/overflows.

The clean no-aux idle capture showed injector, fanout, and emulator injection
signals all low with `csr.mode=0`. In the pre-waitrequest-fix image,
`avs_csr_waitrequest` remained high at idle, which is the reason this report
now tracks the injector CSR fix in addition to the aux fanout removal.

The 2026-04-29 board rerun corrected an earlier debug mistake: the headless
JTAG master in `debug_sc_system_v3.qsys` is not connected to `mm_bridge.s0`.
The old JTAG preset therefore wrote SC byte addresses into an unmapped JTAG
aperture. The script now fails fast; datapath CSR stimulus uses `sc_tool` word
addresses derived from the generated SVD/address map.

## Open Items

The emulator injector path is live on board. Real-source closure remains
blocked at MuTRiG/LVDS lock: a bounded ASIC0 XML configuration command returned
idle cleanly, but `mutrig_frame_deassembly_0` did not advance and the LVDS
controller reports fatal/error counts on most physical lanes. Next debug should
focus on the MuTRiG config bitstream, LVDS training/reset sequence, and the
physical lane/ribbon state before any real-MuTRiG BASIC/PROF rows are credited.
