# Phase 5 Real-MuTRiG MTS Timestamp-Error Debug - 2026-04-29

## Summary

Real MuTRiG lanes 0 and 3 are now proven injector-correlated after ASIC0/ASIC3 XML configuration and channel-16-only overrides, but the default closure path still fails because `mts_processor_0` marks many type-1 hits with the timestamp-error sideband. With `ring_buffer_cam.filter_inerr=1`, all four `hit_stack_subsystem_0.ring_buffer_cam_*` instances count and filter those errored hits. `hit_stack_subsystem_1` stays quiet in the lane0/3-only test, as expected.

This is no longer a zero-hit real-source blocker for lanes 0/3. It is an MTS timestamp-error calibration / sideband generation blocker before BASIC real-MuTRiG cases can pass.

Update after the recompiled frame/MTS/histogram SignalTap image: a strict
retry with normal SC synchronization did not reproduce the ring input-error
condition and passed with zero MTS discards, while an MTS-error trigger timed
out with 0 triggers. A later histogram-statistics-triggered repetition captured
the downstream accepted-hit boundary but recorded one MTS discard. Treat the
blocker as intermittent/not-soak-cleared rather than continuously asserted.

## Evidence

| Run | Result | Key counters | Interpretation |
|---|---|---|---|
| [`phase5_real_mutrig_link_lvdsreset_20260429.md`](phase5_real_mutrig_link_lvdsreset_20260429.md) | diagnostic | lanes 0/3 aligned idle with zero LVDS error counter after reset; lanes 1/2/4/5/6/7 remain fatal/loss-sync | physical/link baseline is only usable on lanes 0/3 in this setup |
| [`phase5_real_mutrig_link_cfg03_ch16_20260429.md`](phase5_real_mutrig_link_cfg03_ch16_20260429.md) | diagnostic | ASIC0/ASIC3 cfg opcodes return idle; channel-enable and `tdctest_n` overrides select channel 16 only | controller path and XML packing command complete; run-window evidence is still required |
| [`phase5_injector_emulator_l0_broadcast_sweep_20260429.md`](phase5_injector_emulator_l0_broadcast_sweep_20260429.md) | PASS | interval `25000/12500/6250` gives histogram hits `14293/28413/55998`, zero drops, zero MTS discards, zero ring input errors | emulator reference path is clean and monotonic with broadcast run-control |
| [`phase5_injector_real03_badlanes_masked_strict_sweep_20260429.md`](phase5_injector_real03_badlanes_masked_strict_sweep_20260429.md) | FAIL | all-channel XML/TDC-test config gives histogram hits scaling with interval, but also MTS discards and large ring input-error counts | original XML/TDC-test setting overdrives or mis-modes the downstream path |
| [`phase5_injector_real03_ch16_strict_20260429.md`](phase5_injector_real03_ch16_strict_20260429.md) | FAIL | hist `38467`, MTS `45852`, MTS discard `0`, frame CRC `0`, ring input errors `68334` | channel-16-only config collapses the rate and clears MTS discards, but MTS still asserts timestamp-error sideband |
| [`phase5_injector_real03_ch16_mtslat65536_20260429.md`](phase5_injector_real03_ch16_mtslat65536_20260429.md) | FAIL | hist `49627`, MTS `46932`, ring input errors `41214` with `EXPECTED_LATENCY=65536` | not only a positive-delay window too small for the default `2000` cycles |
| [`phase5_injector_real03_ch16_mtsfield_e_20260429.md`](phase5_injector_real03_ch16_mtsfield_e_20260429.md) | FAIL | hist `37741`, MTS `44316`, ring input errors `67344` with E-field delay calculation | not simply the T-vs-E delay-source selection |
| [`phase5_injector_real03_ch16_ringfilteroff_20260429.md`](phase5_injector_real03_ch16_ringfilteroff_20260429.md) | diagnostic-only clean | hist `60642`, drops `0`, MTS `44742`, MTS discard `0`, ring input errors `0`, frame CRC `0`, post-end clean | disabling the ring timestamp-error filter lets the path drain cleanly, so the remaining blocker is the MTS error sideband, not histogram/CAM storage |
| [`phase5_frame_hist_mts_histstats_stp_20260429.md`](phase5_frame_hist_mts_histstats_stp_20260429.md) | debug update | MTS-error trigger timed out after a clean strict retry; MTS-valid and histogram-statistics-valid runtime triggers exported VCDs | confirms the real lanes 0/3 path can reach both MTS type-1 and histogram-statistics accepted-hit boundaries in the debug image |
| [`phase5_injector_real03_ch16_mts_valid_stp_20260429.md`](phase5_injector_real03_ch16_mts_valid_stp_20260429.md) | PASS | hist `29629`, MTS `22257`, ring input errors `0`, drops `0`, frame CRC `0` | strict real lanes 0/3 retry passed with no timestamp-error sideband in this 100 ms window |
| [`phase5_injector_real03_ch16_histstats_valid_stp_20260429.md`](phase5_injector_real03_ch16_histstats_valid_stp_20260429.md) | FAIL | hist `30613`, MTS `23617`, ring input errors `0`, MTS discard `1`; SignalTap captured `histogram_statistics_0.asi_hist_fill_in_valid` | downstream acceptance is real, but one discard means the run is not closure-grade |

## Ring Localization

For the strict channel-16 run, `INERR_COUNT` increments only in hit-stack subsystem 0:

| Ring CAM | `INERR_COUNT` delta | `PUSH_COUNT` delta | `POP_COUNT` delta |
|---|---:|---:|---:|
| `hs0_rb0` | 16486 | 7768 | 7768 |
| `hs0_rb1` | 16883 | 8119 | 8119 |
| `hs0_rb2` | 17268 | 8573 | 8573 |
| `hs0_rb3` | 17697 | 8463 | 8463 |
| `hs1_rb0..3` | 0 | 0 | 0 |

The ring-CAM SVD defines this counter as filtered ingress timestamp-error hits (`CTRL[4]=filter_inerr`). That matches the MTS type-1 `aso_hit_type1_error` contract.

## Next Boundary

Keep the current 1180-probe frame/MTS/histogram SignalTap image as the working
debug image. The next capture should be a longer soak or repeated 100 ms run
with two runtime triggers:

- `mts_preprocessor_0.aso_hit_type1_error` high, to catch the next
  timestamp-error sideband event if it reappears.
- `histogram_statistics_0.asi_hist_fill_in_valid` rising edge, to keep proving
  downstream accepted-hit causality while the error trigger is armed in a
  separate run.

Closure requires repeated real-lane 0/3 windows with `ring_inerr_delta=0`,
`mts_discard_delta=0`, histogram drops/underflows/overflows all zero, and
matching emulator reference captures. Lanes 1/2/4/5/6/7 remain a separate
link/fatal blocker unless explicitly waived.
