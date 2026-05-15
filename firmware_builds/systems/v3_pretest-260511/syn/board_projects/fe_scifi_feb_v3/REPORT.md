# v3_pretest-260511 FEB SciFi v3 Board Compile Report

## Summary

The self-contained FEB SciFi v3 board project was regenerated after adding the
48-bit true-hit-timestamp histogram sideband through the pre/post rbCAM paths.
The generated Qsys system uses:

- `mts_processor.hit_type1_out` widened to 87 bits with `true_ts[47:0]` in `data[86:39]`
- `histogram_post_ts_sideband_0` to derive post-rbCAM true hit timestamps from FEB framed words
- `histogram_ingress_bridge_0` with post forwarding trimmed off and histogram data widened to 87 bits
- `histogram_statistics_0` version `26.2.3.0514` with `AVST_DATA_WIDTH=87`, `UPDATE_KEY_BIT_HI=86`, `UPDATE_KEY_BIT_LO=39`, and `LOCK_KEY_RANGES=true`

`qsys-generate` and the full Quartus build both complete with zero errors.
The build is fit-clean at 57,293 / 91,680 ALMs (62%) and produces
`output_files/top.sof`.

Timing signoff remains PARTIAL for the full FEB image because the pre-existing
slow-corner LVDS `pll_sclk` setup path is still negative. The previous recovery
violations are no longer present in this run.

## Build Inputs

- Board project: `firmware_builds/systems/v3_pretest-260511/syn/board_projects/fe_scifi_feb_v3`
- Qsys source: `firmware_builds/systems/v3_pretest-260511/syn/feb_system_v3.qsys`
- Generated QIP: `firmware_builds/systems/v3_pretest-260511/syn/feb_system_v3/synthesis/feb_system_v3.qip`
- Quartus revision: `top`
- Device: `5AGXBA7D4F31C5`
- SignalTap: disabled; no STP files or SignalTap assignments are present in `top.qsf`.

## Qsys Generate

- Command: `bash firmware_builds/systems/v3_pretest-260511/script/generate_feb_system_v3.sh`
- Exit code: 0
- Error count: 0
- Status file: `firmware_builds/systems/v3_pretest-260511/syn/feb_system_v3_qsys_generate_20260514_192347_isolated.status`
- Report: `firmware_builds/systems/v3_pretest-260511/syn/feb_system_v3/feb_system_v3_generation.rpt`
- Result: PASS. The generated QIP includes `histogram_post_ts_sideband`, `histogram_pre_ts_trim`, `histogram_ingress_bridge`, and `histogram_statistics_v2` with `LOCK_KEY_RANGES=true`.

## Quartus Compile

- Command: `quartus_sh --flow compile top`
- Exit code: 0
- Quartus shell elapsed time: `00:40:27`
- Flow elapsed time: `00:39:11`
- Flow report: `output_files/top.flow.rpt`
- Map report: `output_files/top.map.rpt`
- Fit report: `output_files/top.fit.rpt`
- Fit summary: `output_files/top.fit.summary`
- STA summary: `output_files/top.sta.summary`
- SOF: `output_files/top.sof` (12,679,115 bytes)

Quartus reported:

```text
Info: Quartus Prime Analysis & Synthesis was successful. 0 errors, 1638 warnings
Info: Quartus Prime Fitter was successful. 0 errors, 32 warnings
Info: Quartus Prime Assembler was successful. 0 errors, 1 warning
Info: Quartus Prime Timing Analyzer was successful. 0 errors, 26 warnings
Info (293000): Quartus Prime Full Compilation was successful. 0 errors, 1697 warnings
```

## Resource Summary

From `output_files/top.fit.summary`:

| Metric | Result | Gate |
| --- | ---: | ---: |
| Logic utilization | 57,293 / 91,680 ALMs (62%) | < 80% |
| Registers | 86,351 | Informational |
| Pins | 218 / 426 (51%) | Informational |
| Block memory bits | 4,018,378 / 13,987,840 (29%) | Informational |
| RAM blocks | 536 / 1,366 (39%) | Informational |
| DSP blocks | 0 / 800 (0%) | Informational |
| HSSI RX PCS / PMA | 4 / 9 (44%) | Informational |
| HSSI TX PCS / PMA | 8 / 9 (89%) | Informational |
| PLLs | 7 / 21 (33%) | Informational |

## Timing Summary

From `output_files/top.sta.summary`:

| Model | Worst setup slack | Setup TNS | Worst hold slack | Worst recovery slack |
| --- | ---: | ---: | ---: | ---: |
| Slow 1100mV 85C | -1.243 ns | -100.136 ns | +0.202 ns | +1.433 ns |
| Slow 1100mV 0C | -0.950 ns | -28.441 ns | +0.183 ns | +1.748 ns |
| Fast 1100mV 85C | +0.604 ns | 0.000 ns | +0.089 ns | +2.735 ns |
| Fast 1100mV 0C | +0.777 ns | 0.000 ns | +0.071 ns | +3.231 ns |

- Worst setup path: `u_feb_system|u_qsys|data_path_subsystem|lvds_rx_28nm_0|ALTLVDS_RX_component|auto_generated|pll_sclk~PLL_OUTPUT_COUNTER|divclk`
- Timing Analyzer status: PASS as a tool phase, 0 errors and 26 warnings.
- Timing signoff verdict: PARTIAL. Fit, assembler, SOF generation, hold, recovery, removal, and fast-corner setup are clean; slow-corner setup remains open on the LVDS PLL clock path.

## Verdict

PARTIAL PASS for FEB bring-up gate.

- PASS: Qsys generation.
- PASS: Analysis & Synthesis.
- PASS: Fitter capacity, 57,293 / 91,680 ALMs (62%).
- PASS: Assembler and `top.sof` generation.
- PASS: TimeQuest execution as a tool phase.
- OPEN: Slow-corner setup closure on the existing LVDS `pll_sclk` path.
