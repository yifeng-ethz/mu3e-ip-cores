# Phase 5 Real-Lane MTS Input Hiterr Debug - 2026-04-29

## Summary

The intermittent real-lane MTS discard is now localized upstream of MTS.
An input-hiterr runtime trigger captured the bad beat on
`mts_preprocessor_0.asi_hit_type0_error[0]`; the same beat appears four
exported clock samples earlier at
`mutrig_datapath_subsystem_0.mutrig_frame_deassembly_0.aso_hit_type0_error[0]`.
MTS is behaving according to its default `discard_hiterr=1` policy by not
emitting a type-1 hit for that flagged input beat.

This does not close the real-MuTRiG gate. It refines the blocker from
"possible MTS timestamp-error" to "real lane-0 frame-deassembly hiterr on an
otherwise histogram-live lane 0/3 run".

## Evidence Artifacts

| Artifact | Result | Notes |
|---|---|---|
| [`phase5_injector_real03_ch16_repeat5_250ms_20260429.md`](phase5_injector_real03_ch16_repeat5_250ms_20260429.md) | FAIL_DEBUG | 5 repeated 250 ms real-lane windows; 4/5 PASS, run 47052 had one `mts_discard_with_histogram_hits`; histogram drops, ring input errors, frame CRC errors stayed zero. |
| [`phase5_injector_real03_ch16_repeat8_250ms_mts0_input_hiterr_stp_20260429.md`](phase5_injector_real03_ch16_repeat8_250ms_mts0_input_hiterr_stp_20260429.md) | FAIL_DEBUG | 8 repeated 250 ms windows under the input-hiterr trigger; 7/8 PASS, run 47073 had one `mts_discard_with_histogram_hits`; histogram drops, ring input errors, frame CRC errors stayed zero. |
| [`phase5_frame_hist_mts0_input_hiterr_real03_ch16_repeat8_250ms_capture_20260429.log`](phase5_frame_hist_mts0_input_hiterr_real03_ch16_repeat8_250ms_capture_20260429.log) | PASS_DEBUG | SignalTap wrapper returned `capture_rc=0`; runner returned `runner_rc=1` because one repetition hit the expected blocker. |
| [`../captures/phase5_frame_hist_mts0_input_hiterr_real03_ch16_repeat8_250ms_20260429.vcd`](../captures/phase5_frame_hist_mts0_input_hiterr_real03_ch16_repeat8_250ms_20260429.vcd) | PASS_DEBUG | Exported VCD of the input-hiterr trigger. |
| [`../signaltap/phase5_frame_hist_path_mts0_input_hiterr_runtime_20260429.stp`](../signaltap/phase5_frame_hist_path_mts0_input_hiterr_runtime_20260429.stp) | PASS_DEBUG | Presentation-only runtime copy of the compiled frame/hist STP, retargeted to `mts_preprocessor_0.asi_hit_type0_error[0]` rising edge. No tap-list or compiled netlist change. |

## Repeat-Run Results

The no-STP repeat run produced:

| Run | Hist hits | MTS hits | MTS discard delta | Ring input-error delta | Frame CRC delta | Class |
|---:|---:|---:|---:|---:|---:|---|
| 47050 | 31170 | 24505 | 0 | 0 | 0 | PASS |
| 47051 | 32729 | 25197 | 0 | 0 | 0 | PASS |
| 47052 | 32102 | 25828 | 1 | 0 | 0 | `mts_discard_with_histogram_hits` |
| 47053 | 40972 | 35506 | 0 | 0 | 0 | PASS |
| 47054 | 30041 | 23888 | 0 | 0 | 0 | PASS |

The input-hiterr SignalTap repeat run produced:

| Run | Hist hits | MTS hits | MTS discard delta | Ring input-error delta | Frame CRC delta | Class |
|---:|---:|---:|---:|---:|---:|---|
| 47070 | 29113 | 24097 | 0 | 0 | 0 | PASS |
| 47071 | 29115 | 24548 | 0 | 0 | 0 | PASS |
| 47072 | 32007 | 25533 | 0 | 0 | 0 | PASS |
| 47073 | 31777 | 25008 | 1 | 0 | 0 | `mts_discard_with_histogram_hits` |
| 47074 | 32757 | 25066 | 0 | 0 | 0 | PASS |
| 47075 | 32087 | 24449 | 0 | 0 | 0 | PASS |
| 47076 | 30566 | 25072 | 0 | 0 | 0 | PASS |
| 47077 | 28962 | 25267 | 0 | 0 | 0 | PASS |

## VCD Reduction

The input-hiterr VCD contains one trigger edge:

| Exported time | Boundary | Observation |
|---:|---|---|
| 124500 ps | `mutrig_frame_deassembly_0.aso_hit_type0_*` | `valid=1`, `sop=1`, `eop=1`, `error[0]=1`, `error[1]=0`, `error[2]=0`, `channel=0`, `data=0x102885e0000` |
| 128500 ps | `mts_preprocessor_0.asi_hit_type0_*` | `valid=1`, `ready=1`, `sop=1`, `eop=1`, `error[0]=1`, `error[1]=0`, `error[2]=0`, `channel=0`, `data=0x102885e0000` |
| 128500 ps | `mts_preprocessor_0.aso_hit_type1_*` | `valid=0`, `error=0`; no downstream type-1 beat is emitted for the flagged input beat. |

Decoding `0x102885e0000` with the MTS type-0 field layout gives:

| Field | Value |
|---|---:|
| ASIC | 0 |
| channel | 16 |
| TCC | 5186 |
| TFINE | 30 |
| ECC | 0 |

The four-sample delay from frame-deassembly output to MTS input means the
discarded beat is already flagged before it reaches MTS. Per
`mutrig_frame_deassembly/rtl/frame_rcv_ip.vhd`, `aso_hit_type0_error[0]` is
raised from two classes of reason while unpacking a hit: latched
`asi_rx8b1k_error[1:0]` over any byte in the hit, or the decoded hit fields
`T_BadHit` / `E_BadHit`. The current STP did not include those raw input error
bits, parser state, or bad-hit field observables in the same capture window, so
it cannot yet distinguish byte error from bad-hit marker.

## Interpretation

`mutrig_timestamp_processor/mts_processor.vhd` increments `DISCARD_HIT_CNT`
when `asi_hit_type0_accept=1` and `hit_in_ok=0`. With the default
`csr.discard_hiterr=1`, `hit_in_ok` is false when
`asi_hit_type0_error(HITERR_BIT_LOC)` is high. `HITERR_BIT_LOC` is bit 0.

Therefore the observed MTS discard is explained by the captured lane-0
`error[0]` beat. The previous output timestamp-error trigger
(`aso_hit_type1_error`) timing out is consistent with this: the bad input beat
is discarded before type-1 output, not emitted as an output timestamp-error
beat.

## Next Debug Step

Regenerate and compile a narrower lane-0 frame-deassembly SignalTap profile
that includes raw `asi_rx8b1k_data`, `asi_rx8b1k_error[2:0]`, K flags, parser
state/byte counters, the unpacked `T_BadHit` / `E_BadHit` fields if they survive
synthesis, and the type-0 output sideband. The existing
`phase4e_runctl_mts_stage` profile already contains much of this lane-0 raw
boundary and can be retargeted to `mutrig_frame_deassembly_0.aso_hit_type0_error[0]`
or `mts_preprocessor_0.asi_hit_type0_error[0]`. The next closure question is
which frame-deassembly reason source asserts `error[0]` on ASIC0 channel16, not
whether MTS or histogram accept paths are wired.
