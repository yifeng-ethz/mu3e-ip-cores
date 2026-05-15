# v3_pretest-260511-rc-readyless-260511 FEB SciFi v3 Board Project Report

## Status

Qsys generation, run-control fan-out proof, Quartus compile, and SOF/RBF
generation are complete.

This board project was minted from the `v3_pretest-260511-phase4-fix-260511`
template without stale compile databases, incremental databases, or output
files.

The Quartus flow exited 0, but the image is not timing-clean. Slow-corner setup
and recovery violations remain, and TimeQuest reports unconstrained setup/hold
requirements. Treat the SOF as a debug-load candidate only under the FEB
iterative-debug timing relaxation, not as production signoff.

## Build Inputs

- Board project:
  `firmware_builds/systems/v3_pretest-260511-rc-readyless-260511/syn/board_projects/fe_scifi_feb_v3`
- Qsys source:
  `firmware_builds/systems/v3_pretest-260511-rc-readyless-260511/syn/feb_system_v3.qsys`
- Expected generated QIP:
  `firmware_builds/systems/v3_pretest-260511-rc-readyless-260511/syn/feb_system_v3/synthesis/feb_system_v3.qip`
- Quartus revision: `top`
- Device: `5AGXBA7D4F31C5`
- SignalTap: disabled in this non-STP compile candidate.

## Required Evidence

1. `script/generate_feb_system_v3.sh` exits 0 and writes a status file with
   `error_count=0`.
2. The run-control fan-out adapter proof shows that any generated
   ready-to-readyless `timing_adapter` wrapper has `outUseReady=0` and drives
   `in_ready=1`, so it cannot backpressure `run_control_splitter`.
3. `quartus_sh --flow compile top` exits 0 from this board-project directory.
4. `output_files/top.sof` exists and is recorded with size and checksum.
5. Timing/resource summaries are copied into this report and
   `doc/RC_READYLESS_COMPILE.md`.

## Evidence To Date

- Qsys status:
  `../../feb_system_v3_qsys_generate_20260512_005752_isolated.status`
  (`exit_code=0`, `error_count=0`).
- Adapter proof:
  `../../feb_system_v3/synthesis/submodules/feb_system_v3_data_path_subsystem_avalon_st_adapter_018_timing_adapter_0.sv`
  drives `ready[0] = 1` and `in_ready = ready[0]`.
- Quartus compile status:
  `quartus_compile_top_20260512_010600_rcreadyless.status`
  (`exit_code=0`, runtime `2445` s).
- Quartus compile log:
  `quartus_compile_top_20260512_010600_rcreadyless.console.log`
  (`0 errors`, `1580 warnings`).
- SOF:
  `output_files/top.sof`, `12678639` bytes,
  SHA-256 `2171cd90643967aef85993ac384707807ffcf418b1b23652443277bd3f8d3f2e`.
- RBF:
  `output_files/top.rbf`, `6964496` bytes,
  SHA-256 `b3a7c4fa070228b0a0629f9170b7c23056436b7d65e2c43ee5caa1565e23d000`.
- Fitter summary:
  `output_files/top.fit.summary`: `61,193 / 91,680 ALMs (67%)`, `91736`
  registers, `4,032,202 / 13,987,840` block memory bits (29%), `7 / 21` PLLs.
- Timing summary:
  `output_files/top.sta.summary` and `output_files/top.sta.rpt`.
  Worst reported violations are slow 85 C setup slack `-1.029`, slow 85 C
  recovery slack `-1.324`, slow 0 C setup slack `-0.707`, and slow 0 C recovery
  slack `-1.225`.
- Timing constraints:
  `output_files/top.sta.rpt` reports timing not met and unconstrained
  setup/hold requirements.
- Other critical warning:
  Nios RAM init depth mismatch (`16384` design depth vs `32768` init-file
  depth), with Quartus truncating extra init content.
- Compile report:
  `../../../doc/RC_READYLESS_COMPILE.md`.

## SignalTap Gap Revision

A dedicated SignalTap debug revision is compiled for the Phase 4 zero-hit gap:
`top_stp_phase4_rc_readyless_gap`.

Build inputs:

- STP source:
  `../../../signaltap/phase4_rc_readyless_gap.stp`
- Node Finder report:
  `../../../signaltap/phase4_rc_readyless_gap_nodes.md` (`99/99` probes found,
  `0` missing)
- QSF:
  `top_stp_phase4_rc_readyless_gap.qsf`
- Output directory:
  `output_files_stp_phase4_rc_readyless_gap_clkfix`

Compile evidence:

- Console log:
  `quartus_compile_top_stp_phase4_rc_readyless_gap_clkfix_20260512_0328.console.log`
- Full compile result: `Quartus Prime Full Compilation was successful. 0
  errors, 1580 warnings`
- SignalTap map result:
  `Info (35024): Successfully connected in-system debug instance
  "phase4_rc_readyless_gap_lvds" to all 231 required data inputs, trigger
  inputs, acquisition clocks, and dynamic pins`
- Acquisition clock:
  `lvds_outclock_clk`; the earlier internal `lvds_rx_28nm_0_outclock_clk`
  attempt produced a one-connection SignalTap warning and must not be reused.
- QSF CRC metadata is non-zero/mixed, avoiding the all-zero trigger CRC class
  that breaks runtime SignalTap compatibility.

Programming artifacts:

- SOF:
  `output_files_stp_phase4_rc_readyless_gap_clkfix/top_stp_phase4_rc_readyless_gap.sof`,
  `12686909` bytes, SHA-256
  `7dd7f9303a7551d4b0074136a38f2b818ad37e1d20ec4a9decfd6dd21e7f03ad`.
- RBF:
  `output_files_stp_phase4_rc_readyless_gap_clkfix/top_stp_phase4_rc_readyless_gap.rbf`,
  `7013448` bytes, SHA-256
  `70bd0ec7f67d48e500f14dc6232a616f90645eb278606ac25922760bd38e9a6c`.
- JDI:
  `output_files_stp_phase4_rc_readyless_gap_clkfix/top_stp_phase4_rc_readyless_gap.jdi`,
  `92916` bytes, SHA-256
  `362404a223d94d36e24fa0d5c3f4b4c3b061947ab7a68fc9029fc5a49bfa26d9`.

STP timing/resource status:

- Fitter summary:
  `61,643 / 91,680 ALMs (67%)`, `93325` registers,
  `4,133,578 / 13,987,840` block memory bits (30%), `7 / 21` PLLs.
- Slow 85 C setup/recovery fail (`-1.345` / `-1.335`).
- Slow 0 C setup/recovery fail (`-1.177` / `-1.242`).
- Fast 85 C and fast 0 C pass.

Verdict: this STP image is a loadable debug candidate under the FEB
iterative-debug relaxation because 2 of 4 corners pass. It is not production
signoff.

The on-board SignalTap capture is now recorded in
`../../../doc/RC_READYLESS_STP_CAPTURE.md` and
`../../../signaltap/captures/phase4_rc_readyless_gap_20260512_042348/`.
It narrows the zero-hit blocker past run-control and into the emulator output
contract: start-run reaches `emulator_mutrig_0.asi_ctrl`, `run_generating`
asserts, and `frame_rst` deasserts, but `aso_tx8b1k_valid` never asserts while
`aso_tx8b1k_data` remains idle `0x1bc`.

Follow-up byte-stream build action used the current `tx8b1k` decoded-lane mux
wiring. The source Qsys update is captured in
`firmware_builds/systems/v3_pretest-260511/script/apply_v3_byte_stream_contract.sh`,
and regenerated `../../feb_system_v3.sopcinfo` now has eight
`BYTE_STREAM_ENABLE` parameters with the same
`tx8b1k -> decoded_lane_mux_N.in1` wiring. A directed sim at
`../../../tb_int/sim_byte_stream_axis_20260512_0443/summary.txt` shows the
disabled build has zero valid pulses and the enabled build has 16 valid
pulses.

The non-STP byte-stream fix compile passed in
`quartus_compile_top_20260512_0445_byte_stream_fix.console.log` with `0`
errors and `1587` warnings. The generated SOF SHA-256 is
`c8239ef1ab2f0bc21da91e0de41ca4c452531cb363677c43c9fb3f7930712dcd`; timing is
debug-load only, with slow 85C setup worst slack `-2.226 ns`.

Hardware smoke artifacts are under
`../../../hw_smoke/phase4_byte_stream_fix_20260512_0526/`. That smoke restores
post-selected histogram word-counter activity (`hist_rate_dump.log` has
`last_interval_total_hits 7995716`, zero drops, zero underflow, zero overflow),
but that run selected the post input with the post-hit filter disabled.
`sc_hss0_after_hist_rate.log` and `sc_hss1_after_hist_rate.log` keep HSS
frame-assembly actual-hit counters at zero.

The follow-up pre-HSS probe under
`../../../hw_smoke/phase4_pre_hss_probe_20260512_0541/` selected
`hist_snoop_source=pre`; `hist_pre_rate_dump.log` reports all histogram stats
zero and `hist_pre_rate_bins.csv` has `sum(count)=0`. MTS-visible totals,
rbCAM payload counters, and HSS counters also remain zero. The byte-stream
build-contract blocker is fixed; the next debug boundary is upstream of
`histogram_ingress_bridge_0.pre_in` / `mts_preprocessor_0.hit_type1_out`.

The focused pre-HSS SignalTap source for that next boundary is generated at
`../../../signaltap/phase4_pre_hss_gap.stp` from
`../../../script/generate_phase4_pre_hss_gap_stp.py`. Its Node Finder report,
`../../../signaltap/phase4_pre_hss_gap_nodes.md`, shows `76/76` probes found
and `0` missing. It has not yet been imported into a dedicated Quartus revision
or compiled into a loadable image; use `top_stp_phase4_pre_hss_gap` for that
next revision so the existing rc-readyless capture image remains untouched.
