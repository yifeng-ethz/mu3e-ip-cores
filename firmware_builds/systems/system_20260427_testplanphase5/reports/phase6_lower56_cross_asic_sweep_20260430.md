# Phase-6 Lower ASIC5/6 Cross-ASIC Sweep - 2026-04-30

## Conclusion

- ASIC5/lane5 and ASIC6/lane6 each pass alone at one TDC-test channel with pulse-high 4 and zero LVDS error/DPA-unlock deltas.
- The same two real lanes together fail with MTS-forwarded ring input errors; the failure survives 50 ms post-sync/pre-inject settle.
- ASIC6 `ext_trig_offset=0..15` against ASIC5 offset 0 did not find a clean point; every offset failed as `ring_input_errors_with_histogram_hits`.
- A two-lane emulator reference through the same lower MTS/ring path passes after settle, so the blocker is not a generic lower hit-stack inability to accept two lanes.
- The current working hypothesis is real MuTRiG cross-ASIC timestamp/epoch/order coherence before or inside lower MTS, not LVDS training and not SWB/DMA.

## Pulse-Width Sweep

| Case | Class | Hist | MTS | MTS Disc | Ring InErr | Frame | LVDS Err | DPA Unlock |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `lane_0x20_high_3` | `real_source_not_reaching_histogram` | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| `lane_0x20_high_4` | `PASS` | 25570 | 152954 | 0 | 0 | 192251 | 0 | 0 |
| `lane_0x20_high_5` | `PASS` | 18374 | 161498 | 0 | 0 | 203416 | 0 | 0 |
| `lane_0x40_high_3` | `real_source_not_reaching_histogram` | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| `lane_0x40_high_4` | `PASS` | 30104 | 239430 | 0 | 0 | 297662 | 0 | 0 |
| `lane_0x40_high_5` | `PASS` | 39027 | 233154 | 0 | 0 | 294131 | 0 | 0 |
| `lane_0x60_high_3` | `real_source_not_reaching_histogram` | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| `lane_0x60_high_4` | `ring_input_errors_with_histogram_hits` | 74848 | 396933 | 0 | 521526 | 362613 | 0 | 0 |
| `lane_0x60_high_5` | `ring_input_errors_with_histogram_hits` | 3110 | 387081 | 0 | 500504 | 349213 | 0 | 0 |

## ASIC6 Header Offset Sweep

| ASIC6 ext_trig_offset | Class | Hist | MTS | Ring InErr | Frame | LVDS Err | DPA Unlock |
|---:|---|---:|---:|---:|---:|---:|---:|
| 0 | `ring_input_errors_with_histogram_hits` | 77798 | 387030 | 503689 | 357316 | 0 | 0 |
| 1 | `ring_input_errors_with_histogram_hits` | 89000 | 385710 | 512014 | 359171 | 0 | 0 |
| 2 | `ring_input_errors_with_histogram_hits` | 25611 | 381440 | 497915 | 348314 | 0 | 0 |
| 3 | `ring_input_errors_with_histogram_hits` | 92095 | 406921 | 528052 | 365851 | 0 | 0 |
| 4 | `ring_input_errors_with_histogram_hits` | 42488 | 394091 | 509680 | 358127 | 0 | 0 |
| 5 | `ring_input_errors_with_histogram_hits` | 57005 | 401805 | 525162 | 364570 | 0 | 0 |
| 6 | `ring_input_errors_with_histogram_hits` | 87380 | 592386 | 732306 | 504011 | 0 | 0 |
| 7 | `ring_input_errors_with_histogram_hits` | 48961 | 423216 | 548211 | 384448 | 0 | 0 |
| 8 | `ring_input_errors_with_histogram_hits` | 65522 | 392983 | 511924 | 359472 | 0 | 0 |
| 9 | `ring_input_errors_with_histogram_hits` | 82878 | 398050 | 515543 | 360475 | 0 | 0 |
| 10 | `ring_input_errors_with_histogram_hits` | 81050 | 386856 | 497548 | 350890 | 0 | 0 |
| 11 | `ring_input_errors_with_histogram_hits` | 57860 | 418260 | 538020 | 376839 | 0 | 0 |
| 12 | `ring_input_errors_with_histogram_hits` | 54245 | 376071 | 510463 | 356837 | 0 | 0 |
| 13 | `ring_input_errors_with_histogram_hits` | 94319 | 395083 | 507127 | 357032 | 0 | 0 |
| 14 | `ring_input_errors_with_histogram_hits` | 76723 | 408510 | 532130 | 371042 | 0 | 0 |
| 15 | `ring_input_errors_with_histogram_hits` | 100770 | 401763 | 513179 | 357842 | 0 | 0 |

## Structural References

| Case | Class | Hist | MTS | MTS Disc | Ring InErr | Frame | LVDS Err | DPA Unlock |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| `emulator_lanes56_high4_settle` | `PASS` | 53522 | 480756 | 0 | 0 | 597192 | - | - |
| `real_lanes56_high4_settle` | `ring_input_errors_with_histogram_hits` | 88893 | 384043 | 0 | 504266 | 356042 | 0 | 0 |
| `lane5` | `PASS` | 26348 | 155774 | 0 | 0 | 193920 | 0 | 0 |
| `lane6` | `PASS` | 50851 | 237550 | 0 | 0 | 298430 | 0 | 0 |
| `pair56` | `ring_input_errors_with_histogram_hits` | 95851 | 387451 | 0 | 497696 | 349494 | 0 | 0 |

## Phase-6 Runner Replay

Updated runner: `phase6_long_runs/20260430_190036`.

| Case | Classification | Phase-5 Class | Hist | MTS | Ring InErr | LVDS Err | DPA Unlock |
|---|---|---|---:|---:|---:|---:|---:|
| `P6B006` | `expected_pass` | `PASS` | 59922 | 167262 | 0 | 0 | 0 |
| `P6B007` | `expected_pass` | `PASS` | 50603 | 255228 | 0 | 0 | 0 |
| `P6B010` | `unexpected_fail` | `ring_input_errors_with_histogram_hits` | 89774 | 415796 | 534904 | 0 | 0 |
| `P6B020` | `expected_fail` | `ring_input_errors_with_histogram_hits` | 2610549 | 10255643 | 9712754 | 0 | 0 |
| `P6E010` | `underfilled` | `PASS` | 3994 | 20708 | 0 | 0 | 0 |

## Raw Evidence

- `pulse_sweep`: `firmware_builds/systems/system_20260427_testplanphase5/reports/phase6_sweeps/lower56_ch1_pulse_20260430_183559`
- `asic6_offset_sweep`: `firmware_builds/systems/system_20260427_testplanphase5/reports/phase6_sweeps/lower56_ch1_offset6_20260430_184158`
- `emulator_ref`: `firmware_builds/systems/system_20260427_testplanphase5/reports/phase6_sweeps/lower56_structural_ref_settle_20260430_185043`
- `real_settle`: `firmware_builds/systems/system_20260427_testplanphase5/reports/phase6_sweeps/lower56_real_settle_20260430_185117`
- `delay_bin_probe`: `firmware_builds/systems/system_20260427_testplanphase5/reports/phase6_sweeps/lower56_delay_bins_20260430_185329`
