# Phase 4 Emulator-Type0 Round 2 Compile

Date: 2026-05-12

## Purpose

Compile the FEB v3 emulator-type0 Qsys refactor after the Round 1 tb_int/FEB+SWB co-run passed.

## Inputs

- Build directory: `firmware_builds/systems/v3_pretest-260511-emulator-type0-260512`
- Qsys generate status: `syn/feb_system_v3_qsys_generate_20260512_095900_isolated.status`
- Quartus project: `syn/board_projects/fe_scifi_feb_v3/top.qpf`

## Commands

```sh
firmware_builds/systems/v3_pretest-260511-emulator-type0-260512/script/generate_feb_system_v3.sh
quartus_sh --flow compile top
```

## Qsys Generate Verdict

- Status file: `syn/feb_system_v3_qsys_generate_20260512_095900_isolated.status`
- `exit_code=0`
- Search path used the local whitelist from `script/qsys_search_path.sh`.
- Generated `feb_system_v3` contains `emulator_mutrig_qsys_inst : component emulator_mutrig_qsys_lane`; the instance label intentionally differs from the component name to avoid a Quartus VHDL name collision.

## Quartus Compile Verdict

- Status file: `syn/board_projects/fe_scifi_feb_v3/quartus_compile_top_20260512_101045_emutype0.status`
- Log file: `syn/board_projects/fe_scifi_feb_v3/quartus_compile_top_20260512_101045_emutype0.console.log`
- `exit_code=0`
- Quartus result: `Full Compilation was successful. 0 errors, 1975 warnings`
- Fitter result: `Fitter was successful. 0 errors, 30 warnings`
- Timing Analyzer result: `Timing Analyzer was successful. 0 errors, 24 warnings`

## Bitstream

- SOF: `syn/board_projects/fe_scifi_feb_v3/output_files/top.sof`
- Size: 13 MiB
- SHA256: `11cce55e14610d4cf902d6e6fac7de14268b13bcdf6bc0cd6576f052049c615a`
- RBF: `syn/board_projects/fe_scifi_feb_v3/output_files/top.rbf`
- Size: 6.7 MiB

## Resource Summary

From `output_files/top.fit.summary`:

- Logic utilization: `65,890 / 91,680 ALMs (72%)`
- Registers: `100769`
- Block memory bits: `3,961,842 / 13,987,840 (28%)`
- RAM blocks: `518 / 1,366 (38%)`
- PLLs: `7 / 21 (33%)`

## STA Summary

The compile produced a usable SOF, but the inherited LVDS receive-clock setup path still misses the relaxed timing gate:

- Setup slacks across timing models: `-1.331 ns`, `-0.923 ns`, `0.620 ns`, `0.796 ns`
- Hold slacks across timing models: `0.195 ns`, `0.173 ns`, `0.085 ns`, `0.070 ns`
- Worst recovery slack: `0.432 ns`
- Worst removal slack: `0.206 ns`
- Worst minimum pulse-width slack: `0.160 ns`

This is not final STA closure. It is sufficient for the next iterative-debug board probe because the failing path is the inherited LVDS receive clock path, while the Phase 4 emulator-type0 path under test is internally generated.

## Verdict

Round 2 compile: **PASS for bitstream generation, FAIL for final timing closure**. Proceed to controlled on-board Phase 4 probe with this SOF, then decide whether another compile is justified by the board result.
