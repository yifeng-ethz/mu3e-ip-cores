# v3_pretest-260511 FEB SciFi v3 Board Compile Report

## Summary

The self-contained FEB SciFi v3 board project was minted under this directory with a clean single-revision `top.qpf` / `top.qsf`, no SignalTap assignments, and a local `top.qip` that resolves the generated `feb_system_v3` QIP under `firmware_builds/systems/v3_pretest-260511/syn/`.

`qsys-generate` completed successfully after the `histogram_statistics_v2` BOOLEAN package rollback, and Quartus Analysis & Synthesis now passes the previous generic-type failure point. The Quartus full compile still fails in Fitter because the regenerated design exceeds the selected Arria V device capacity.

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
- Runtime: 41 s
- Console log: `firmware_builds/systems/v3_pretest-260511/syn/feb_system_v3_qsys_generate_20260511_115955.console.log`
- Status file: `firmware_builds/systems/v3_pretest-260511/syn/feb_system_v3_qsys_generate_20260511_115955.status`
- Report: `firmware_builds/systems/v3_pretest-260511/syn/feb_system_v3/feb_system_v3_generation.rpt`
- Result: PASS. The report contains `Info: qsys-generate succeeded.` and no `Error:` lines.

## Phase 4 - Quartus Compile

- Command: `quartus_sh --flow compile top`
- Exit code: 3
- Total runtime: Quartus flow report lists 00:47:17 total elapsed time.
- Console log: attached terminal run in Codex; persisted evidence is in the Quartus reports below.
- Flow report: `firmware_builds/systems/v3_pretest-260511/syn/board_projects/fe_scifi_feb_v3/output_files/top.flow.rpt`
- Map summary: `firmware_builds/systems/v3_pretest-260511/syn/board_projects/fe_scifi_feb_v3/output_files/top.map.summary`
- Fit report: `firmware_builds/systems/v3_pretest-260511/syn/board_projects/fe_scifi_feb_v3/output_files/top.fit.rpt`
- Fit summary: `firmware_builds/systems/v3_pretest-260511/syn/board_projects/fe_scifi_feb_v3/output_files/top.fit.summary`
- STA summary: not generated because Fitter failed before the assembler/STA stages.

Quartus reported:

```text
Info: Quartus Prime Analysis & Synthesis was successful. 0 errors, 1544 warnings
Error (170012): Fitter requires 14867 LABs to implement the design, but the device contains only 9168 LABs
Error (11802): Can't fit design in device.
Error: Quartus Prime Fitter was unsuccessful. 2 errors, 31 warnings
Error (293001): Quartus Prime Full Compilation was unsuccessful. 4 errors, 1575 warnings
```

## Resource Summary

| Metric | Result | Gate |
| --- | ---: | ---: |
| Logic utilization | 146,935 / 91,680 ALMs (160%) | < 90% |
| Total LABs | 14,867 / 9,168 LABs needed (162%) | <= 100% |
| Registers | 236,672 | Informational |
| Pins | 218 / 426 (51%) | Informational |
| Block memory bits | 2,823,882 / 13,987,840 (20%) | Informational |
| HSSI RX PCS | 4 / 9 (44%) | Informational |
| HSSI TX PCS | 8 / 9 (89%) | Informational |
| PLLs | 7 / 21 (33%) | Informational |

The design fails the ALM utilization gate and cannot proceed to STA.

## Timing Summary

| Clock | Setup slack |
| --- | ---: |
| Not available | STA did not run because Fitter failed. |

- Worst setup slack: not available.
- Negative setup slack clocks: not available.
- Bring-up timing verdict: FAIL. The build did not reach STA, so the FEB bring-up tolerance of slack >= -0.4 ns on this Slow 85C build cannot be evaluated.

## Blocker

The over-capacity condition is localized in the regenerated data path. The current hierarchy shows:

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

The current qsys generation resolves `ring_buffer_cam` from `ring-buffer_cam/script/ring_buffer_cam_hw.tcl`, whose package is version `26.2.10.0507` and emits the SystemVerilog files `ring_buffer_cam_sv_pkg.sv`, `ring_buffer_cam_fifo.sv`, `ring_buffer_cam_core.sv`, and `ring_buffer_cam.sv`. The Apr 27 fit hierarchy used the VHDL implementation `ring_buffer_cam_v2_core`. Switching that implementation or changing the Qsys/IP package selection is a functional packaging decision, so it was not silently worked around in this board-project mint.

## Verdict

FAIL for FEB bring-up gate. The `histogram_statistics_v2` BOOLEAN-vs-NATURAL mismatch and stale missing-component path are resolved far enough for A&S to pass, but the compile cannot produce a `.sof`, fit summary with passing utilization, or STA summary until the `ring_buffer_cam` implementation/version selection is resolved.
