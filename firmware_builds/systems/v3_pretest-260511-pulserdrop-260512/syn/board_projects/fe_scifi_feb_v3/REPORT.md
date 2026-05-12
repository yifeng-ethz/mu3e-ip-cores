# v3_pretest-260511 FEB SciFi v3 Board Compile Report

## 2026-05-12 nominal integration STA rerun

Verdict: **FAIL at integration 1.0x nominal clocks**.

The active board project STA inputs are already nominal integration clocks. No
standalone-IP 1.1x timing scale was found in the loaded SDC/Tcl inputs. A
no-refit `quartus_sta top -c top` rerun on the existing fit database still
fails slow-corner setup and recovery:

| Corner | Setup WNS | Hold WNS | Recovery WNS | Removal WNS |
| --- | ---: | ---: | ---: | ---: |
| Slow 1100 mV 85 C | -1.245 ns | +0.182 ns | -1.344 ns | +0.457 ns |
| Slow 1100 mV 0 C | -1.076 ns | +0.170 ns | -1.243 ns | +0.353 ns |
| Fast 1100 mV 85 C | +0.660 ns | +0.075 ns | +1.195 ns | +0.270 ns |
| Fast 1100 mV 0 C | +0.812 ns | +0.060 ns | +1.296 ns | +0.208 ns |

No SOF promotion. Failure trace:
`firmware_builds/systems/v3_pretest-260511-pulserdrop-260512/doc/STA_FAIL_TRACE.md`.

## Summary

The self-contained FEB SciFi v3 board project was minted under this directory with a clean single-revision `top.qpf` / `top.qsf`, no SignalTap assignments, and a local `top.qip` that resolves the generated `feb_system_v3` QIP under `firmware_builds/systems/v3_pretest-260511/syn/`.

`qsys-generate` completed successfully after the rbCAM submodule bump to the M10K-inferred SystemVerilog implementation. The previous Fitter capacity failure is resolved: the post-fix full Quartus compile reaches Fitter, Assembler, and Timing Analyzer successfully and produces `output_files/top.sof`.

The build is fit-clean at 61,385 / 91,680 ALMs (67%). TimeQuest still reports negative slow-corner setup and recovery slack on pre-existing integration clocks, so the capacity closure is PASS and the timing signoff remains PARTIAL.

## Build Inputs

- Board project: `firmware_builds/systems/v3_pretest-260511/syn/board_projects/fe_scifi_feb_v3`
- Qsys source symlink: `firmware_builds/systems/v3_pretest-260511/syn/feb_system_v3.qsys`
- Qsys source target: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/quartus_systems/feb_system_v3.qsys`
- Generated QIP: `firmware_builds/systems/v3_pretest-260511/syn/feb_system_v3/synthesis/feb_system_v3.qip`
- `histogram_statistics` submodule: `56d5c46` (`[FIX] Restore histogram_statistics_v2 boolean Qsys parameters`)
- Quartus revision: `top`
- Device: `5AGXBA7D4F31C5`
- SignalTap: disabled; no STP files or SignalTap assignments are present in `top.qsf`.

## Phase 3 - Qsys Generate

- Exit code: 0
- Error count: 0
- Runtime: approximately 33 s from the Qsys log timestamps
- Console log: `firmware_builds/systems/v3_pretest-260511/syn/feb_system_v3_qsys_generate_20260511_164511_isolated.console.log`
- Status file: `firmware_builds/systems/v3_pretest-260511/syn/feb_system_v3_qsys_generate_20260511_164511_isolated.status`
- Report: `firmware_builds/systems/v3_pretest-260511/syn/feb_system_v3/feb_system_v3_generation.rpt`
- Search path: 64 active IP paths from the current repo, with `firmware_builds/systems/*/syn` and `firmware_builds/systems/system_20260427_testplanphase5` excluded.
- Isolated catalog: enabled through a temporary Qsys user catalog, preventing stale user `ipx` entries from the Apr 27 reference snapshot from being scanned.
- IP version bumps required: none.
- Result: PASS. The report contains `Info: qsys-generate succeeded.` and no `Error:` lines. The generated synthesis submodules include `cam_primitive_m10k_sv.sv`, confirming that Qsys resolved the post-fix rbCAM package.

## Phase 4 - Quartus Compile

- Command: `quartus_sh --flow compile top`
- Exit code: 0
- Total runtime: 2245 s; Quartus shell reported 00:37:25 elapsed.
- Console log: `firmware_builds/systems/v3_pretest-260511/syn/board_projects/fe_scifi_feb_v3/quartus_compile_top_20260511_164654_postm10k.console.log`
- Status file: `firmware_builds/systems/v3_pretest-260511/syn/board_projects/fe_scifi_feb_v3/quartus_compile_top_20260511_164654_postm10k.status`
- Flow report: `firmware_builds/systems/v3_pretest-260511/syn/board_projects/fe_scifi_feb_v3/output_files/top.flow.rpt`
- Map summary: `firmware_builds/systems/v3_pretest-260511/syn/board_projects/fe_scifi_feb_v3/output_files/top.map.summary`
- Fit report: `firmware_builds/systems/v3_pretest-260511/syn/board_projects/fe_scifi_feb_v3/output_files/top.fit.rpt`
- Fit summary: `firmware_builds/systems/v3_pretest-260511/syn/board_projects/fe_scifi_feb_v3/output_files/top.fit.summary`
- STA summary: `firmware_builds/systems/v3_pretest-260511/syn/board_projects/fe_scifi_feb_v3/output_files/top.sta.summary`
- SOF: `firmware_builds/systems/v3_pretest-260511/syn/board_projects/fe_scifi_feb_v3/output_files/top.sof` (12,679,822 bytes)

Quartus reported:

```text
Info: Quartus Prime Analysis & Synthesis was successful. 0 errors, 1524 warnings
Fitter Status : Successful - Mon May 11 17:21:23 2026
Info: Quartus Prime Assembler was successful.
Info: Quartus Prime Timing Analyzer was successful. 0 errors, 24 warnings
Info (293000): Quartus Prime Full Compilation was successful. 0 errors, 1579 warnings
```

## Resource Summary

| Metric | Result | Gate |
| --- | ---: | ---: |
| Logic utilization | 61,385 / 91,680 ALMs (67%) | < 80% |
| Registers | 91,888 | Informational |
| Pins | 218 / 426 (51%) | Informational |
| Block memory bits | 4,032,202 / 13,987,840 (29%) | Informational |
| RAM blocks | 540 / 1,366 (40%) | Informational |
| HSSI RX PCS | 4 / 9 (44%) | Informational |
| HSSI TX PCS | 8 / 9 (89%) | Informational |
| PLLs | 7 / 21 (33%) | Informational |

The design passes the FEB capacity gate after rbCAM slot storage moved back into block RAM.

## Timing Summary

| Model | Worst setup slack | Setup TNS | Worst hold slack | Recovery slack |
| --- | ---: | ---: | ---: | ---: |
| Slow 1100mV 85C | -1.080 ns | -162.611 ns | +0.244 ns | -1.307 ns |
| Slow 1100mV 0C | -0.877 ns | -50.006 ns | +0.200 ns | -1.213 ns |
| Fast 1100mV 85C | +0.613 ns | 0.000 ns | +0.128 ns | +1.201 ns |
| Fast 1100mV 0C | +0.786 ns | 0.000 ns | +0.107 ns | +1.308 ns |

- Worst setup path: `u_feb_system|u_qsys|data_path_subsystem|lvds_rx_28nm_0|ALTLVDS_RX_component|auto_generated|pll_sclk~PLL_OUTPUT_COUNTER|divclk`.
- Worst recovery path: `lvds_firefly_clk`.
- Timing Analyzer status: PASS as a tool phase, 0 errors and 24 warnings.
- Timing signoff verdict: PARTIAL. Fit and SOF generation are clean, but the slow-corner setup and recovery violations remain open integration timing work.

## Blocker

The previous over-capacity condition was localized in the regenerated data path. Before the rbCAM M10K fix, the failed fit hierarchy showed:

| Hierarchy | ALMs needed |
| --- | ---: |
| `feb_system_v3_data_path_subsystem:data_path_subsystem` | 130,466.6 |
| `hit_stack_subsystem_0` | 52,662.5 |
| `hit_stack_subsystem_1` | 52,437.0 |
| `ring_buffer_cam_0..3` under `hit_stack_subsystem_0` | 12,680.6 to 12,980.6 each |
| `ring_buffer_cam_0..3` under `hit_stack_subsystem_1` | 12,571.1 to 12,857.2 each |

For comparison, the read-only Apr 27 reference fit report at `firmware_builds/systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/output_files/top.fit.rpt` reports:

| Reference hierarchy | ALMs needed |
| --- | ---: |
| Full design | 66,346.2 |
| `feb_system_v3_data_path_subsystem:data_path_subsystem` | 50,447.5 |
| `ring_buffer_cam_0..3` under each hit stack | about 2,300 to 2,359 each |

The failed capacity run resolved `ring_buffer_cam` from the pre-fix SystemVerilog package, whose slot arrays were implemented as registers. The Apr 27 fit hierarchy used the VHDL implementation `ring_buffer_cam_v2_core`, which kept the slot storage in M10K-backed CAM memory.

The post-fix qsys generation resolves `ring_buffer_cam` from the bumped submodule revision that includes package version `26.2.11.0511` and `cam_primitive_m10k_sv.sv`. Fitter now reports 67% ALM utilization and 40% RAM block utilization, matching the expected return to block-RAM-backed slot storage.

## Verdict

PARTIAL PASS for FEB bring-up gate.

- PASS: Qsys generation.
- PASS: Analysis & Synthesis.
- PASS: Fitter capacity, 61,385 / 91,680 ALMs (67%).
- PASS: Assembler and `top.sof` generation.
- PASS: TimeQuest execution.
- OPEN: Slow-corner setup and recovery timing closure.
