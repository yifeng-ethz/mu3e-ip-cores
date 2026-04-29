# Phase 5 Injector SignalTap Compile Report

- Date: `2026-04-28`
- Updated: `2026-04-29`
- Quartus project: `syn/board_projects/fe_scifi_feb_v3/top`
- Revision: `top_stp_pipe_phase5_injector`
- Status: `MICRO_STP_TIMING_PASS`
- Board action: programmed once; runtime capture blocked by host SC path

## Summary

The 2026-04-28 injector-path SignalTap build was structurally coherent but not timing-closed. Both attempted tap profiles imported cleanly, connected all post-map SignalTap pins, completed fit and assembly, and then failed the LVDS setup corner in STA. The same-day no-STP baseline failed the same LVDS setup corner, proving the immediate block was baseline firmware timing rather than SignalTap insertion.

The 2026-04-29 regenerated no-STP baseline, after the histogram timing fixes (`hit_fifo` diagnostic peak register path plus registered `rr_arbiter` select/pop), is timing-clean. The injector micro STP revision was then regenerated, imported, mapped, fitted, assembled, and timing-analyzed against that timing-clean database. It passes STA and is now the current injector-path programming candidate. The old 2026-04-28 compact/micro STP SOFs are stale and must not be programmed.

| Profile | Requested probes | Post-map STP pins | Map/Fit/ASM | STA result | Evidence |
|---|---:|---:|---|---|---|
| `compact` | 84 | 201/201 connected | PASS | FAIL, WNS `-0.877 ns` at slow 85 C and `-0.669 ns` at slow 0 C | `map_top_stp_pipe_phase5_injector_cleanstp_20260428.log`, `fit_top_stp_pipe_phase5_injector_cleanstp_20260428.log`, `asm_top_stp_pipe_phase5_injector_cleanstp_20260428.log`, `sta_top_stp_pipe_phase5_injector_cleanstp_20260428.log` |
| `micro` | 31 | 95/95 connected | PASS | FAIL, WNS `-0.906 ns` at slow 85 C and `-0.778 ns` at slow 0 C | `phase5_injector_path_lvds_micro_prepare_20260428.log`, `map_top_stp_pipe_phase5_injector_microstp_20260428.log`, `fit_top_stp_pipe_phase5_injector_microstp_20260428.log`, `asm_top_stp_pipe_phase5_injector_microstp_20260428.log`, `sta_top_stp_pipe_phase5_injector_microstp_20260428.log` |
| `no-STP baseline` | 0 | n/a | PASS | FAIL, WNS `-0.998 ns` at slow 85 C and `-0.790 ns` at slow 0 C | `map_top_nostp_pipe_phase5_baseline_20260428.log`, `fit_top_nostp_pipe_phase5_baseline_20260428.log`, `asm_top_nostp_pipe_phase5_baseline_20260428.log`, `sta_top_nostp_pipe_phase5_baseline_20260428.log` |
| `no-STP baseline after histogram timing fix` | 0 | n/a | PASS | PASS, slow 85 C setup WNS `+0.266 ns` overall / `+0.463 ns` LVDS `pll_sclk`; slow 0 C setup WNS `+0.306 ns` overall / `+0.596 ns` LVDS `pll_sclk`; all TNS `0.000` | `output_files_pipe/top_nostp_pipe.fit.summary`, `output_files_pipe/top_nostp_pipe.asm.rpt`, `output_files_pipe/top_nostp_pipe.sta.summary`, `output_files_pipe/top_nostp_pipe.sof` |
| `micro after histogram timing fix` | 31 | 95/95 connected | PASS | PASS, slow 85 C setup WNS `+0.337 ns` overall / `+0.447 ns` LVDS `pll_sclk`; slow 0 C setup WNS `+0.521 ns` LVDS `pll_sclk`; all TNS `0.000` | `phase5_injector_path_lvds_micro_prepare_20260429.log`, `map_top_stp_pipe_phase5_injector_microstp_20260429.log`, `fit_top_stp_pipe_phase5_injector_microstp_20260429.log`, `asm_top_stp_pipe_phase5_injector_microstp_20260429.log`, `sta_top_stp_pipe_phase5_injector_microstp_20260429.log`, `output_files_pipe_phase5_injector_stp/top_stp_pipe_phase5_injector.sof` |

## Gate Decision

`INJ-STP-NODES` passes: the generated `.stp` is valid and Quartus can import it.

`INJ-STP-COMPILE` passes for the rebuilt 2026-04-29 micro profile. This image was programmed once because map, fit, assembler, and STA all complete with 0 errors and all reported TNS values are `0.000`. Runtime capture is tracked in `phase5_injector_signaltap_runtime_20260429.md` and is currently blocked by the host SC/PCIe binding path, not by this compile gate.

## No-STP Baseline

`top_nostp_pipe` was rebuilt after the STP failures to isolate instrumentation from baseline firmware timing. The first baseline failed; the 2026-04-29 baseline after regenerating Qsys with the histogram timing fixes passes.

| Checkpoint | Stage | Result | Key lines |
|---|---|---|---|
| 2026-04-28 pre-fix | Map | PASS | 0 errors, 1682 warnings, elapsed `00:06:22` |
| 2026-04-28 pre-fix | Fit | PASS | 0 errors, 36 warnings, placement successful, routing successful without retry, elapsed `00:28:02` |
| 2026-04-28 pre-fix | Assembler | PASS | 0 errors, 7 warnings, elapsed `00:00:50` |
| 2026-04-28 pre-fix | STA | FAIL | slow 85 C WNS `-0.998 ns`, TNS `-17.659`; slow 0 C WNS `-0.790 ns`, TNS `-10.668`; both failures are on `u_feb_system|u_qsys|data_path_subsystem|lvds_rx_28nm_0|ALTLVDS_RX_component|auto_generated|pll_sclk~PLL_OUTPUT_COUNTER|divclk` |
| 2026-04-29 histogram timing fix | Map | PASS | 0 errors, 1681 warnings, elapsed `00:06:00`; generated `feb_system_v3_pipe` uses `rr_arbiter` revision `1.2` and `histogram_statistics_v2` revision `1.6` |
| 2026-04-29 histogram timing fix | Fit | PASS | 0 errors, 36 warnings, elapsed `00:35:50`; fit used one automatic routing retry on `ring_buffer_cam_2|pop_engine_state.FLUSHING` |
| 2026-04-29 histogram timing fix | Assembler | PASS | 0 errors, 7 warnings, elapsed `00:00:49`; `top_nostp_pipe.sof` timestamp `2026-04-29 02:04:18 +0200` |
| 2026-04-29 histogram timing fix | STA | PASS | 0 errors, 21 warnings; slow 85 C setup WNS `+0.266 ns`, hold `+0.245 ns`, LVDS setup `+0.463 ns`; slow 0 C setup WNS `+0.306 ns`, hold `+0.211 ns`, LVDS setup `+0.596 ns`; fast 0 C hold worst `+0.125 ns`; all listed TNS `0.000` |

## Rebuilt Micro STP

`top_stp_pipe_phase5_injector` was rebuilt with the current micro SignalTap profile after the histogram timing fixes were regenerated into Qsys.

| Stage | Result | Key lines |
|---|---|---|
| Prepare/import | PASS | `phase5_injector_path_lvds_micro_prepare_20260429.log`; profile `micro`, 31 requested probes, 31 found, 0 missing; `quartus_stp --enable --stp_file` completed |
| Map | PASS | `map_top_stp_pipe_phase5_injector_microstp_20260429.log`; 0 errors, 1681 warnings; SignalTap instance connected to all 95 required data/trigger/acquisition/dynamic pins |
| Fit | PASS | `fit_top_stp_pipe_phase5_injector_microstp_20260429.log`; 0 errors, 36 warnings, elapsed `00:28:39`; 63,393 / 91,680 ALMs (69%), 550 / 1,366 RAM blocks (40%) |
| Assembler | PASS | `asm_top_stp_pipe_phase5_injector_microstp_20260429.log`; 0 errors, 7 warnings; `top_stp_pipe_phase5_injector.sof` timestamp `2026-04-29 02:51:05 +0200` |
| STA | PASS | `sta_top_stp_pipe_phase5_injector_microstp_20260429.log`; 0 errors, 21 warnings; slow 85 C setup WNS `+0.337 ns`, hold `+0.185 ns`, LVDS setup `+0.447 ns`; slow 0 C setup WNS `+0.521 ns` on LVDS `pll_sclk`, hold `+0.167 ns`; fast 0 C hold worst `+0.063 ns`; all listed TNS `0.000` |

## Next Debug Step

Restore `/dev/mudaq0` by rebinding the PCIe endpoint to the `mudaq` driver, then retry the rebuilt 2026-04-29 micro STP capture for `INJ-P1-EMU-LIVE`. Do not use the old 2026-04-28 compact or micro SOFs; rebuild any wider tap profile from the timing-clean database before programming it.
