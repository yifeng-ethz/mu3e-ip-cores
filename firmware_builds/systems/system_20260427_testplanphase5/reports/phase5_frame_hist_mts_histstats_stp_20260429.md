# Phase 5 Frame/Histogram SignalTap Runtime - 2026-04-29

## Summary

The recompiled `top_stp_pipe_phase5_frame_hist` debug image is usable for
Phase-5 frame/MTS/histogram runtime captures. The first MTS output
timestamp-error trigger timed out because the real-lane retry did not produce
`mts_preprocessor_0.aso_hit_type1_error`. Retargeting the same compiled tap
list at runtime to valid-hit boundaries captured both the real-MuTRiG lanes
0/3 path and the emulator lane-0 reference at the histogram-statistics input.
A later runtime trigger on `mts_preprocessor_0.asi_hit_type0_error[0]` caught
the intermittent discard and localized it to an upstream lane-0
frame-deassembly hit-error beat.

This is debug evidence, not timing signoff: the debug STP revision compiled
with 0 Quartus errors but has slow 85 C setup WNS `-0.860 ns` on the LVDS
`pll_sclk` generated clock. The no-STP image remains the timing-signoff image.

## Build And Runtime Evidence

| Step | Result | Artifact | Notes |
|---|---|---|---|
| STP node validation | PASS | [`../signaltap/phase5_frame_hist_path.nodes.md`](../signaltap/phase5_frame_hist_path.nodes.md) | 1180/1180 probes found after adding MTS debug stream and hit-stack-0 debug ports. |
| STP import | PASS | [`../signaltap/phase5_frame_hist_path.stp`](../signaltap/phase5_frame_hist_path.stp) | `quartus_stp top -c top_stp_pipe_phase5_frame_hist --enable --stp_file=...` completed with 0 errors / 0 warnings. |
| Quartus compile | PASS_DEBUG_ONLY | [`../syn/logs/quartus_compile_top_stp_pipe_phase5_frame_hist_mts_tserr_20260429.console.log`](../syn/logs/quartus_compile_top_stp_pipe_phase5_frame_hist_mts_tserr_20260429.console.log) | Full compile `rc=0`, 0 errors, 1701 warnings; debug-only timing caveat above. |
| Program FPGA | PASS | [`../syn/board_projects/fe_scifi_feb_v3/program_top_stp_pipe_phase5_frame_hist_mts_tserr_20260429.log`](../syn/board_projects/fe_scifi_feb_v3/program_top_stp_pipe_phase5_frame_hist_mts_tserr_20260429.log) | Programmed `output_files_pipe_phase5_frame_hist_stp/top_stp_pipe_phase5_frame_hist.sof`, checksum `0x16D84D15`. |
| PCIe / SC recovery | PASS | command log in terminal session | `sudo -n /usr/local/sbin/mudaq_recover_pcie` reloaded `mudaq`; `rc_tool send stop-reset --feb 7` echoed `0x31`; `check_sc_bridges.py --skip-jtag` passed on retry. |

## SC Wrapper Finding

The concurrent SignalTap wrapper used to force `BOARD_TEST_SC_NO_RESET=1`.
After FPGA reprogramming this left the FEB SC secondary ring stale: injector
CSR writes to `0x0AC80` timed out with no matching secondary reply, while the
same write succeeded immediately when `sc_tool` used its normal synchronization.
`run_phase5_injector_signaltap_capture.py` now makes no-reset opt-in via
`--runner-no-sc-reset`.

## Captures

| Capture | Runner | SignalTap | Key observation |
|---|---|---|---|
| [`phase5_frame_hist_mts0_tserr_real03_ch16_capture_20260429.log`](phase5_frame_hist_mts0_tserr_real03_ch16_capture_20260429.log) | FAIL | TIMEOUT | Pre-patch wrapper forced SC no-reset; first injector CSR write timed out, so no MTS trigger was expected. |
| [`phase5_frame_hist_mts0_tserr_real03_ch16_capture_retry_20260429.log`](phase5_frame_hist_mts0_tserr_real03_ch16_capture_retry_20260429.log) | PASS | TIMEOUT | Real lanes 0/3 channel-16 periodic run passed with `hist=28069`, `MTS=23127`, `ring_inerr=0`; MTS error trigger saw 0 triggers. |
| [`phase5_frame_hist_mts0_valid_real03_ch16_capture_20260429.log`](phase5_frame_hist_mts0_valid_real03_ch16_capture_20260429.log) | PASS | PASS | Runtime trigger on `mts_preprocessor_0.aso_hit_type1_valid`; VCD shows MTS0 type-1 valid, no MTS error, and no hit-stack-0 error. |
| [`phase5_frame_hist_histstats_valid_real03_ch16_capture_20260429.log`](phase5_frame_hist_histstats_valid_real03_ch16_capture_20260429.log) | FAIL | PASS | Runtime trigger on `histogram_statistics_0.asi_hist_fill_in_valid`; VCD shows downstream accept/queue sequence. Runner had one MTS discard, so this repetition is not closure. |
| [`phase5_frame_hist_histstats_valid_emulator_l0_capture_20260429.log`](phase5_frame_hist_histstats_valid_emulator_l0_capture_20260429.log) | PASS | PASS | Same histogram-statistics trigger on emulator lane 0; downstream VCD sequence matches the real-lane capture shape. |
| [`phase5_frame_hist_mts0_error_real03_ch16_repeat5_250ms_capture_20260429.log`](phase5_frame_hist_mts0_error_real03_ch16_repeat5_250ms_capture_20260429.log) | PASS | TIMEOUT | Runtime trigger still on output `aso_hit_type1_error`; 5/5 repeated real windows passed with no MTS discards, so no output timestamp-error trigger was expected. |
| [`phase5_frame_hist_mts0_input_hiterr_real03_ch16_repeat8_250ms_capture_20260429.log`](phase5_frame_hist_mts0_input_hiterr_real03_ch16_repeat8_250ms_capture_20260429.log) | FAIL | PASS | Runtime trigger on `mts_preprocessor_0.asi_hit_type0_error[0]`; 7/8 windows passed and one window reproduced the MTS discard. VCD localizes the flagged beat to lane-0 frame-deassembly output before MTS. |

## VCD Boundary Summary

Extracted scalar rising-edge counts over the 1024-sample exported VCD windows:

| VCD | `aso_hist_valid` | `post_hist_word_accept` | `hist_stats.asi_hist_fill_in_valid` | `hist_stats.queue_hit_valid` | MTS0 error | hit-stack-0 error |
|---|---:|---:|---:|---:|---:|---:|
| [`../captures/phase5_frame_hist_histstats_valid_real03_ch16_20260429.vcd`](../captures/phase5_frame_hist_histstats_valid_real03_ch16_20260429.vcd) | 1 | 1 | 1 | 1 | 0 | 0 |
| [`../captures/phase5_frame_hist_histstats_valid_emulator_l0_20260429.vcd`](../captures/phase5_frame_hist_histstats_valid_emulator_l0_20260429.vcd) | 1 | 1 | 1 | 1 | 0 | 0 |

Both captures trigger at the histogram-statistics input and show the queue
valid pulse 17 ns later in the exported timebase. The evidence proves the
real lanes 0/3 and emulator lane-0 paths can both reach the histogram
statistics acceptance boundary in the programmed debug image.

## MTS Input-Hiterr Localization

The follow-up input-hiterr capture is reduced in
[`phase5_real03_mts_input_hiterr_debug_20260429.md`](phase5_real03_mts_input_hiterr_debug_20260429.md).
The key VCD facts are:

| Exported time | Boundary | Observation |
|---:|---|---|
| 124500 ps | `mutrig_frame_deassembly_0.aso_hit_type0_*` | `valid=1`, `sop=1`, `eop=1`, `error[0]=1`, `error[1]=0`, `error[2]=0`, `data=0x102885e0000` |
| 128500 ps | `mts_preprocessor_0.asi_hit_type0_*` | same flagged ASIC0/channel16 beat, `ready=1` |
| 128500 ps | `mts_preprocessor_0.aso_hit_type1_*` | `valid=0`, `error=0`; the flagged input beat is discarded before type-1 output. |

Decoded fields for `0x102885e0000`: ASIC 0, channel 16, TCC 5186, TFINE 30,
ECC 0. This shifts the current blocker from an MTS output timestamp-error
question to a lane-0 frame-deassembly hit-error classification question.

## Current Interpretation

The earlier high `ring_inerr_delta` condition is not reproduced in the clean
strict retry. However, the later histogram-triggered and input-hiterr repeated
real runs record an intermittent MTS discard while still producing accepted
histogram hits. Treat the real-MuTRiG Phase-5 BASIC rows as still blocked for
closure until:

1. The real lanes 0/3 channel-16 strict run is repeated over a longer window
   with `ring_inerr_delta=0`, `mts_discard_delta=0`, and no histogram drops.
2. A lane-0 frame-deassembly debug STP captures the raw 8b/10b input and
   internal reason that asserts `aso_hit_type0_error[0]` on ASIC0/channel16.
3. Lanes 1/2/4/5/6/7 are either recovered, masked with a written waiver, or
   assigned separate blocked case rows.
