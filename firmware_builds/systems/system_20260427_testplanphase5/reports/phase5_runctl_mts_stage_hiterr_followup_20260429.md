# Phase-5 Runctl/MTS-Stage Hit-Error Follow-Up - 2026-04-29

## Summary

The fresh `top_stp_pipe_runctl_mts_stage` image was compiled, programmed, and
used to retry the lane-0 frame-deassembly hit-error debug from
`phase5_real03_mts_input_hiterr_debug_20260429.md`.

Result: the previous `mutrig_frame_deassembly_0.aso_hit_type0_error[0]`
condition did not recur. The directed SignalTap trigger timed out cleanly, and
the accompanying repeated datapath runs passed with zero MTS discards and zero
downstream error counters.

## Firmware And Probe Gate

| Item | Result |
|---|---|
| Revision | `top_stp_pipe_runctl_mts_stage` |
| SOF | `output_files_pipe_runctl_mts_stage_stp/top_stp_pipe_runctl_mts_stage.sof` |
| SOF timestamp | 2026-04-29 10:07 |
| SOF checksum | `0x145AA92C` |
| Program target | `USB-BlasterII [7-2]`, Arria V `0x02A020DD` |
| Program result | PASS, 0 errors / 0 warnings |
| Quartus result | full compile PASS, 0 errors / 1829 warnings |
| Fitter | PASS, 0 errors / 38 warnings |
| Assembler | PASS, 0 errors / 1 warning |
| STA | PASS, 0 errors / 23 warnings; debug image has slow-model setup WNS `-0.109 ns` and remains debug-only |

The map report still issues the broad SignalTap partial-connection warning:
`runctl_mts_stage` connects 539 of 741 counted pins. Targeted inspection shows
the probes needed for this follow-up are connected:

- `mutrig_frame_deassembly_0.asi_rx8b1k_data[8:0]`
- `mutrig_frame_deassembly_0.asi_rx8b1k_error[2:0]`
- `mutrig_frame_deassembly_0.asi_rx8b1k_channel[3:0]`
- `mutrig_frame_deassembly_0.asi_rx8b1k_valid`
- `mutrig_frame_deassembly_0.i_data[7:0]`
- `mutrig_frame_deassembly_0.i_byteisk`
- `mutrig_frame_deassembly_0.p_frame_flags[5:0]`
- `mutrig_frame_deassembly_0.p_frame_len[9:0]`
- `mutrig_frame_deassembly_0.aso_hit_type0_error[2:0]`
- `mutrig_frame_deassembly_0.aso_hit_type0_channel[3:0]`
- `mutrig_frame_deassembly_0.aso_hit_type0_startofpacket`
- `mutrig_frame_deassembly_0.aso_hit_type0_endofpacket`

The missing SignalTap pins are stale/nonessential probes, mainly other
lane/error-bit lost-fanout signals and unrelated FIFO internals.

## Post-Flash Sanity

| Gate | Result | Evidence |
|---|---|---|
| PCIe/UIO recovery | PASS | `/usr/local/sbin/mudaq_recover_pcie`, `/dev/mudaq0` recreated at 2026-04-29 10:10 |
| Run-control reset | PASS | `rc_tool send stop-reset --feb 7`, state echo `0x31` |
| SC bridge audit | PASS | histogram, ingress bridge, emulator, source mux, debug run-control, and upload run-control UIDs reachable |
| Environmental monitors | PASS | `phase5_environment_20260429_runctl_mts_stage.md/json`, 62 PASS / 1 WARN / 0 FAIL |

OneWire reports UID `0x4F574D43`, six DQ lines, clear CRC/init flags, and six
non-default temperatures (`29.938`, `33.250`, `21.625`, `22.000`, `40.375`,
`40.188` C). Firefly 2 remains the expected absent/dangling sentinel. The only
environment warning is the existing Firefly 1 VCC raw-code scaling issue.

## SignalTap Retry

| Item | Value |
|---|---|
| STP | `signaltap/phase4e_runctl_mts_stage_fda0_hiterr_runtime_20260429.stp` |
| Trigger | `mutrig_frame_deassembly_0.aso_hit_type0_error[0] == rising edge` |
| Capture log | `phase5_runctl_mts_stage_fda0_hiterr_real03_ch16_repeat12_capture_20260429.log` |
| Capture VCD | none; no trigger, timeout |
| Runner report | `phase5_injector_real03_ch16_repeat12_250ms_fda0_hiterr_stp_20260429.md/json` |

The capture reached `PRE` with 0 triggers seen and ended in `TIMEOUT` after
320 s. This is evidence that the specific lane-0 hit-error trigger did not fire
during the repeated run, not a positive waveform capture.

The concurrent runner passed all 12 windows:

| Metric | Sum | Min / case | Max / case |
|---|---:|---:|---:|
| Histogram hits | 374601 | 29251 | 33295 |
| MTS hits | 297090 | 23875 | 25884 |
| Frame actual-hit delta | 369876 | 29856 | 32061 |
| Histogram drops | 0 | 0 | 0 |
| MTS discards | 0 | 0 | 0 |
| Ring input errors | 0 | 0 | 0 |
| Frame CRC errors | 0 | 0 | 0 |
| Frame missing hits | 0 | 0 | 0 |

## SC-Only Soak

After the SignalTap timeout, the same real-lanes-0/3, channel-16-only mixed
source configuration was rerun without JTAG:

| Item | Value |
|---|---|
| Runner report | `phase5_injector_real03_ch16_repeat40_250ms_post_hiterr_timeout_20260429.md/json` |
| Runs | 40 windows, run numbers `47200`..`47239` |
| Source | `mixed`, real lanes `0` and `3`, emulator-selected lanes `1,2,4,5,6,7` disabled |
| Injector mode | periodic, interval `12500`, pulse high `5`, duration `250 ms` |

| Metric | Sum | Min / case | Max / case |
|---|---:|---:|---:|
| Histogram hits | 1313689 | 29342 | 52587 |
| MTS hits | 1044510 | 23598 | 46449 |
| Frame actual-hit delta | 1301236 | 29636 | 52652 |
| Histogram drops | 0 | 0 | 0 |
| MTS discards | 0 | 0 | 0 |
| Ring input errors | 0 | 0 | 0 |
| Frame CRC errors | 0 | 0 | 0 |
| Frame missing hits | 0 | 0 | 0 |

## Interpretation

The previous intermittent MTS discard remains explained as a flagged input beat
from `mutrig_frame_deassembly_0`, not as an MTS output timestamp error. The new
evidence shows that after a fresh compile/program and SC recovery, the same
real-lane 0/3 injector condition can run 52 total windows with zero recurrence
of the flagged beat and zero downstream drops.

This does not fully close the Phase-5 real-source gate yet. The gate still needs
a longer zero-discard soak and either recovery or explicit waiver of lanes
`1,2,4,5,6,7`. The next useful debug step, if the error recurs, is to keep this
same SignalTap trigger armed and capture the raw 8b/10b error/channel and parser
context at the first `aso_hit_type0_error[0]` edge.
