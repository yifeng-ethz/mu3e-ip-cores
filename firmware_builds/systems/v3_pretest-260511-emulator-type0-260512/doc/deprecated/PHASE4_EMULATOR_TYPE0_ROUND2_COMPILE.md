# Phase 4 Emulator Type0 Round 2 Compile

Date: 2026-05-12
Build: `firmware_builds/systems/v3_pretest-260511-emulator-type0-260512`
Board project: `syn/board_projects/fe_scifi_feb_v3`
SOF: `syn/board_projects/fe_scifi_feb_v3/output_files/top.sof`

## Purpose

Round 2 takes the Round 1 emulator-type0 topology into the FEB v3 Quartus build, regenerates the Platform Designer system through Tcl, and produces the retest SOF for on-board Phase 4.

## Qsys Regeneration

- Applied the build-local Tcl refactor through `script/apply_v3_emulator_type0_qsys.sh`.
- Generated `syn/feb_system_v3.qsys` with `script/generate_feb_system_v3.sh` and the canonical isolated search path.
- Included the build-local `quartus_systems/` and `ip/hit_type0_fanout8/` search roots.
- Excluded historical `firmware_builds/systems/*/syn/` generated trees from the Qsys catalog.
- Generation status: `syn/feb_system_v3_qsys_generate_20260512_110700_isolated.status`, `exit_code=0`, `error_count=0`.
- Generated `*.qsys` files are not writable after regeneration; edits stayed in Tcl recipes.

Topology checks:

| Check | Result |
|---|---|
| Type0 emulator instance name | `emulator_mutrig_qsys_inst` |
| Emulator cluster lanes | `CLUSTER_LANE_COUNT_DEFAULT => 8` |
| Emulator byte stream mode | `BYTE_STREAM_ENABLE => false` |
| Arbiter lanes | 8 generated `lane_0..lane_7` instances |
| Arbiter default mode | 8 x `MODE_DEFAULT => 1` |
| Readyless run-control timing adapters | None in run-control mux, run-control splitter, emulator-control splitter, or `arb_hit_type0_supercore_0` |
| CSR timing mitigation | Added one pipelined Avalon-MM bridge per arbiter lane (`csr_pipe_0..csr_pipe_7`) |

## Compile Attempts

| Stamp | Result | Notes |
|---|---|---|
| `20260512_101045_emutype0` | Exit 0, timing failed | Found new slow85 setup miss, worst `pll_sclk=-1.331 ns`, from Platform Designer command mux into `arb_hit_type0` CSR counters. |
| `20260512_110230_emutype0_csrpipe` | Exit 3 | Compile stopped on generated VHDL duplicate name: instance label matched component name `emulator_mutrig_qsys_lane`. |
| `20260512_111100_emutype0_csrpipe2` | Exit 0, timing failed | CSR path was removed; remaining misses were unrelated FEB frame-assembly/LVDS interconnect paths. |
| `20260512_115400_emutype0_perf` | Exit 0, timing failed | Final retest SOF generated with speed physical synthesis and router timing optimization enabled. |

Final compile status:

- Status: `syn/board_projects/fe_scifi_feb_v3/quartus_compile_top_20260512_115400_emutype0_perf.status`
- Console: `syn/board_projects/fe_scifi_feb_v3/quartus_compile_top_20260512_115400_emutype0_perf.console.log`
- Start/end: 2026-05-12 11:56:14 to 12:50:30 Europe/Zurich.
- Analysis & Synthesis: successful, 0 errors, 1487 warnings.
- Fitter: successful, 0 errors, 29 warnings.
- Assembler: successful, 0 errors, 0 warnings.
- Timing Analyzer: successful, 0 errors, 23 warnings, timing requirements not met.
- Full compilation: successful, 0 errors, 1539 warnings.

## Resources

From `output_files/top.fit.summary`:

| Resource | Usage |
|---|---:|
| Logic utilization | 77,053 / 91,680 ALMs (84%) |
| Registers | 117,650 |
| Block memory bits | 4,016,568 / 13,987,840 (29%) |
| RAM blocks | 528 / 1,366 (39%) |
| DSP blocks | 0 / 800 (0%) |
| HSSI RX PCSs | 4 / 9 (44%) |
| HSSI TX PCSs | 8 / 9 (89%) |
| PLLs | 7 / 21 (33%) |

## Timing

Round 2 does not meet the requested non-STP signoff target of setup slack >= 0 ns on all 4 corners. It does meet the debug-image relaxed envelope used for STP-armed iteration: 2/4 setup corners clean and worst setup slack >= -0.4 ns.

Final setup summary from `output_files/top.sta.summary`:

| Corner | Worst setup slack | TNS | Notes |
|---|---:|---:|---|
| Slow 1100 mV 85 C | -0.369 ns | -3.142 ns | Worst clock `transceiver_pll_clock[0]`; LVDS `pll_sclk` is -0.163 ns. |
| Slow 1100 mV 0 C | -0.156 ns | -0.272 ns | LVDS `pll_sclk` is -0.001 ns. |
| Fast 1100 mV 85 C | 0.619 ns | 0.000 ns | Clean. |
| Fast 1100 mV 0 C | 0.797 ns | 0.000 ns | Clean. |

Slow85 detailed timing evidence:

- Status: `syn/board_projects/fe_scifi_feb_v3/quartus_sta_round2_final_slow85_20260512_125500.status`
- Worst path report: `syn/board_projects/fe_scifi_feb_v3/round2_sta/round2_transceiver_pll_clock_setup_paths.rpt`
- LVDS path report: `syn/board_projects/fe_scifi_feb_v3/round2_sta/round2_lvds_pll_sclk_setup_paths.rpt`

The final worst setup path is inside FEB frame assembly on `transceiver_pll_clock[0]`, not inside the new emulator type0 fanout or arbiter CSR path.

## SOF Identity

`sha256sum`:

| File | SHA256 |
|---|---|
| `output_files/top.sof` | `55d1f09361c75e7fdcf5a404e056e5b8cf458a6d38fb024c3d94ebe9590d7b46` |
| `output_files/top.rbf` | `410b8911029c76ba2cb5c06b0ab413178d3ef7f2c1dc8015915c1a0802db6cb5` |

## Verdict

Round 2 produced a valid Quartus output image and removed the new emulator CSR timing failure, but it is a timing-risk retest SOF rather than clean non-STP timing signoff. Proceeding to Round 3 is acceptable for the Phase 4 emulator-path board check only if the timing risk is carried forward explicitly.
