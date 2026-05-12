# RC-Readyless Compile Report

Build: `v3_pretest-260511-rc-readyless-260511`
Date: 2026-05-12

## Status

Qsys generation, run-control fan-out proof, Quartus compile, and SOF/RBF
generation are complete.

The Quartus flow exited 0, but the build is **not timing-clean**. Slow-corner
setup/recovery violations remain, and TimeQuest reports unconstrained setup and
hold requirements. Treat this as a hardware debug-load candidate only if the
bench owner accepts the FEB iterative-debug timing relaxation; it is not a
production/signoff image.

## Qsys Generation

- Command wrapper: `script/generate_feb_system_v3.sh`
- Status:
  `syn/feb_system_v3_qsys_generate_20260512_005752_isolated.status`
- Console log:
  `syn/feb_system_v3_qsys_generate_20260512_005752_isolated.console.log`
- Generation report: `syn/feb_system_v3/feb_system_v3_generation.rpt`
- Exit code: `0`
- Qsys error count: `0`

## Run-Control Fan-Out Proof

The generated rc-readyless system still contains
`feb_system_v3_data_path_subsystem_avalon_st_adapter_018_timing_adapter_0.sv`
on the ready-to-readyless sink conversions, so a literal `timing_adapter` grep
is not a valid pass/fail gate.

The relevant generated wrapper is non-backpressuring:

- `feb_system_v3_data_path_subsystem_avalon_st_adapter_018.v` has
  `outUseReady = 0` for the sink side.
- `feb_system_v3_data_path_subsystem_avalon_st_adapter_018_timing_adapter_0.sv`
  drives `ready[0] = 1` and `in_ready = ready[0]`, so the adapter cannot hold
  a `run_control_splitter_outN_ready` low.
- `feb_system_v3_data_path_subsystem.vhd` routes splitter outputs
  `0,1,2,3,4,5,7,8,9,10,11,12,13` through that non-backpressuring adapter
  class.
- Splitter outputs `6`, `14`, and `15` connect directly to ready/valid
  consumers (`hit_stack_subsystem_0`, `hit_stack_subsystem_1`, and
  `emulator_ctrl_splitter`).

Proof line anchors:

- `syn/feb_system_v3/synthesis/submodules/feb_system_v3_data_path_subsystem_avalon_st_adapter_018.v:24`
- `syn/feb_system_v3/synthesis/submodules/feb_system_v3_data_path_subsystem_avalon_st_adapter_018.v:194`
- `syn/feb_system_v3/synthesis/submodules/feb_system_v3_data_path_subsystem_avalon_st_adapter_018_timing_adapter_0.sv:95`
- `syn/feb_system_v3/synthesis/submodules/feb_system_v3_data_path_subsystem_avalon_st_adapter_018_timing_adapter_0.sv:98`
- `syn/feb_system_v3/synthesis/submodules/feb_system_v3_data_path_subsystem.vhd:5543`
- `syn/feb_system_v3/synthesis/submodules/feb_system_v3_data_path_subsystem.vhd:6631`
- `syn/feb_system_v3/synthesis/submodules/feb_system_v3_data_path_subsystem.vhd:7018`

Adapter proof verdict: **PASS for compile gate**. The generated fan-out no
longer has a known run-control ready-backpressure blocker.

## Quartus Compile

Command:

```bash
cd firmware_builds/systems/v3_pretest-260511-rc-readyless-260511/syn/board_projects/fe_scifi_feb_v3
/data1/intelFPGA/18.1/quartus/bin/quartus_sh --flow compile top
```

- Status:
  `syn/board_projects/fe_scifi_feb_v3/quartus_compile_top_20260512_010600_rcreadyless.status`
- Console log:
  `syn/board_projects/fe_scifi_feb_v3/quartus_compile_top_20260512_010600_rcreadyless.console.log`
- Runtime: `2445` s (`2026-05-12T01:06:00+02:00` to
  `2026-05-12T01:46:45+02:00`)
- Exit code: `0`
- Flow result: `Quartus Prime Full Compilation was successful. 0 errors,
  1580 warnings`
- Timing analyzer result: `0 errors, 24 warnings`

Generated programming files:

- SOF: `syn/board_projects/fe_scifi_feb_v3/output_files/top.sof`
  - size: `12678639` bytes
  - SHA-256:
    `2171cd90643967aef85993ac384707807ffcf418b1b23652443277bd3f8d3f2e`
- RBF: `syn/board_projects/fe_scifi_feb_v3/output_files/top.rbf`
  - size: `6964496` bytes
  - SHA-256:
    `b3a7c4fa070228b0a0629f9170b7c23056436b7d65e2c43ee5caa1565e23d000`

Primary report artifacts:

- Flow: `syn/board_projects/fe_scifi_feb_v3/output_files/top.flow.rpt`
- Fitter summary:
  `syn/board_projects/fe_scifi_feb_v3/output_files/top.fit.summary`
- Timing report:
  `syn/board_projects/fe_scifi_feb_v3/output_files/top.sta.rpt`
- Timing summary:
  `syn/board_projects/fe_scifi_feb_v3/output_files/top.sta.summary`
- Map summary:
  `syn/board_projects/fe_scifi_feb_v3/output_files/top.map.summary`

Resource summary:

- Device: `5AGXBA7D4F31C5`
- Logic utilization: `61,193 / 91,680 ALMs (67%)`
- Total registers: `91736`
- Pins: `218 / 426 (51%)`
- Block memory bits: `4,032,202 / 13,987,840 (29%)`
- RAM blocks: `540 / 1,366 (40%)`
- DSP blocks: `0 / 800 (0%)`
- HSSI RX PCSs / PMA deserializers: `4 / 9 (44%)`
- HSSI TX PCSs / PMA serializers: `8 / 9 (89%)`
- PLLs: `7 / 21 (33%)`

Timing status:

- **Not clean**: `top.sta.rpt` reports `Critical Warning (332148): Timing
  requirements not met` at lines 3009 and 3738.
- **Not fully constrained**: `top.sta.rpt` reports unconstrained setup and hold
  requirements at lines 5306 and 5307.
- Slow 1100 mV 85 C setup, LVDS RX `pll_sclk` divclk:
  slack `-1.029`, TNS `-138.950`.
- Slow 1100 mV 85 C setup, `transceiver_pll_clock[0]`:
  slack `-0.223`, TNS `-0.842`.
- Slow 1100 mV 85 C recovery, `lvds_firefly_clk`:
  slack `-1.324`, TNS `-4110.829`.
- Slow 1100 mV 0 C setup, LVDS RX `pll_sclk` divclk:
  slack `-0.707`, TNS `-60.808`.
- Slow 1100 mV 0 C recovery, `lvds_firefly_clk`:
  slack `-1.225`, TNS `-3804.867`.

Other compile critical warning:

- `Critical Warning (127004)`: the Nios RAM memory depth is `16384`, while
  the inherited memory initialization file depth is `32768`; Quartus truncated
  the extra init content.

## Flash Gate

This build has a valid SOF/RBF artifact, but it is not a production flash
candidate because timing is not clean and constraints are incomplete.

For the Phase 4 hardware-first debug loop, it may be used only as a debug-load
candidate under the FEB iterative-debug timing relaxation and after shared-bench
approval. The hardware retest documented in `TEST_PLAN.md` §4.10 has now been
run and still shows zero hit flow after run-control and direct
`dbg_mm2runctrl` injection.

The follow-up SignalTap gap image is documented in
`doc/RC_READYLESS_STP_COMPILE.md`. That STP revision compiles successfully and
was loaded for the next hardware-first debug iteration, but it is still not
production timing closure. The on-board capture is documented in
`doc/RC_READYLESS_STP_CAPTURE.md`: start-run reaches the emulator control leaf
and `run_generating` asserts, but `aso_tx8b1k_valid` never asserts.

The next evidence must come from a regenerated fix candidate. The current
generated system wires `emulator_mutrig_N.tx8b1k` into the decoded-lane muxes
while leaving the emulator instances at `BYTE_STREAM_ENABLE=false`; that build
axis intentionally drives idle K28.5 and no `tx8b1k` valid.

## Byte-Stream Fix Candidate

The next generated candidate keeps the `tx8b1k` decoded-lane mux path and sets
`BYTE_STREAM_ENABLE=true` on all eight `emulator_mutrig_N` Qsys instances.

Source/update evidence:

- Recipe:
  `firmware_builds/systems/v3_pretest-260511/script/update_v3_byte_stream_contract.tcl`
- Wrapper:
  `firmware_builds/systems/v3_pretest-260511/script/apply_v3_byte_stream_contract.sh`
- Source systems:
  `quartus_systems/scifi_datapath_system_v3{,_pipe,_lat4}.qsys`, eight true
  byte-stream parameters per file.

Generated Qsys evidence:

- Status:
  `syn/feb_system_v3_qsys_generate_20260512_044214_byte_stream_fix_isolated.status`
- Console log:
  `syn/feb_system_v3_qsys_generate_20260512_044214_byte_stream_fix_isolated.console.log`
- Exit code: `0`
- Qsys error count: `0`
- Regenerated `.sopcinfo`: eight `BYTE_STREAM_ENABLE` parameters under the
  emulator instances, with the existing lane mux wiring
  `emulator_mutrig_N.tx8b1k -> decoded_lane_mux_N.in1` preserved.

Simulation evidence:

- Run directory:
  `tb_int/sim_byte_stream_axis_20260512_0443/`
- `BYTE_STREAM_ENABLE=0`: `valid_high_count=0`, `first_valid_ps=None`.
- `BYTE_STREAM_ENABLE=1`: `valid_high_count=16`,
  `first_valid_ps=12708000`.

Quartus result:

- Compile log:
  `syn/board_projects/fe_scifi_feb_v3/quartus_compile_top_20260512_0445_byte_stream_fix.console.log`
- Flow result: `Quartus Prime Full Compilation was successful. 0 errors,
  1587 warnings`; elapsed `00:37:42`, CPU `02:02:51`.
- SOF:
  `syn/board_projects/fe_scifi_feb_v3/output_files/top.sof`,
  SHA-256 `c8239ef1ab2f0bc21da91e0de41ca4c452531cb363677c43c9fb3f7930712dcd`,
  size `12678659`.
- RBF:
  `syn/board_projects/fe_scifi_feb_v3/output_files/top.rbf`,
  SHA-256 `5dc37ae000a5e37a677f8dcae0a62e769416675342a8409a88f86807e4951bd1`,
  size `7079716`.
- Fitter resources: `65,358 / 91,680` ALMs (`71%`), `101241` registers,
  HSSI TX `8 / 9` (`89%`), RAM blocks `556 / 1,366` (`41%`).
- Timing status: debug-load only, not production signoff. Slow 85C setup worst
  slack is `-2.226 ns`; slow 85C recovery worst slack is `-1.339 ns`.

Post-selected hardware smoke:

- Artifact directory:
  `hw_smoke/phase4_byte_stream_fix_20260512_0526/`.
- Programming and recovery logs:
  `program_feb.log`, `mudaq_recover_pcie.log`.
- JTAG run-control setup:
  `jtag_setup_start.log`, `runctl_last_cmd=0x00020012`.
- Rate histogram:
  `hist_rate_dump.log` reports `underflow_count 0`, `overflow_count 0`,
  `dropped_hits 0`, `total_hits 836042`, and
  `last_interval_total_hits 7995716` after the 1.1 s wait. This run selected
  the histogram bridge `post` input with `post_hit_filter_enabled 0`, so this
  is word-counter activity, not legal-hit conservation evidence.
- Histogram CSV:
  `hist_rate_bins.csv` sums to `7995716` counts, all in bin `0`.
- SC readback after the rate dump:
  `sc_hist_after_rate_0x0A908_len11.log` returns `TOTAL_HITS=0x001C9282`,
  `DROPPED_HITS=0`, `LAST_INT_HITS=0x007A0144`,
  `UNDERFLOW=0`, and `OVERFLOW=0`.
- HSS frame assembly is not fixed by this candidate:
  `sc_hss0_after_hist_rate.log` and `sc_hss1_after_hist_rate.log` show
  declared/actual/missing counters still zero.

Pre-HSS boundary probe:

- Artifact directory:
  `hw_smoke/phase4_pre_hss_probe_20260512_0541/`.
- JTAG setup:
  `jtag_setup_pre_start.log` uses `hist_snoop_source=pre`,
  `selector={source pre ...}`, and reaches `runctl_last_cmd=0x00020012`.
- Histogram dump:
  `hist_pre_rate_dump.log` reports `live_select_post 0`, all stats zero after
  the 1.1 s wait, and `hist_pre_rate_bins.csv` has `sum(count)=0`.
- SC readbacks:
  `sc_hist_pre_after_rate_0x0A908_len11.log` returns `TOTAL_HITS=0`,
  `LAST_INT_HITS=0`, `DROPPED_HITS=0`, `UNDERFLOW=0`, `OVERFLOW=0`;
  MTS-visible totals, rbCAM payload counters, and HSS declared/actual/missing
  counters stay at zero.

Verdict:

The byte-stream candidate is a hardware-positive fix for the old
`aso_tx8b1k_valid=0` build-contract blocker, but not a Phase 4 closure image.
The next hardware-first debug boundary is upstream of the pre-HSS stream:
post-selected histogram word-counter activity is nonzero, while
`histogram_ingress_bridge_0.pre_in` / `mts_preprocessor_0.hit_type1_out`,
rbCAM, and HSS remain zero.

Focused SignalTap prep for that boundary is complete at the source/probe-name
level:

- Generator:
  `script/generate_phase4_pre_hss_gap_stp.py`.
- STP:
  `signaltap/phase4_pre_hss_gap.stp`.
- Node Finder report:
  `signaltap/phase4_pre_hss_gap_nodes.md`, `76/76` probes found and `0`
  missing.

This pre-HSS tap has not yet been imported into a dedicated Quartus revision or
compiled into a loadable SOF. Use `top_stp_phase4_pre_hss_gap` as the next
revision name to avoid disturbing the already-captured
`top_stp_phase4_rc_readyless_gap` image.
