# Phase 6 LVDS Blocker Probe - 2026-04-30

## Scope

One short Phase-6 cycle was run with LVDS SVD snapshots enabled in the
real-source injector sanity path:

```text
firmware_builds/systems/system_20260427_testplanphase5/script/run_phase6_long_soak.py
  --max-cycles 1
  --sleep-seconds 0
  --run-dir firmware_builds/systems/system_20260427_testplanphase5/reports/phase6_lvds_probe_20260430_101630
  --no-run-dma-when-feb-passes
```

Raw run directory:

```text
firmware_builds/systems/system_20260427_testplanphase5/reports/phase6_lvds_probe_20260430_101630/
```

The raw directory is intentionally ignored by git. This file is the promoted
reduced evidence.

## Result

Preflight passed: reset-link commands, SC bridge audit, and environment monitor
audit all returned `rc=0`.

| Case | Stimulus | Classification | Hist hits | MTS hits | Ring input errors | LVDS error delta | LVDS DPA unlock delta |
|---|---|---|---:|---:|---:|---:|---:|
| P6B010 | lanes 5+6, one TDC-test channel per ASIC, 100 kHz, pulse-high 4 | `expected_pass` | 112490 | 431650 | 0 | 0 | 0 |
| P6B020 | lanes 5+6, full 32 TDC-test channels per ASIC, 100 kHz, pulse-high 4 | `expected_fail` / `ring_input_errors_with_histogram_hits` | 2606816 | 9687243 | 2052049 | 0 | 0 |
| P6E010 | lanes 5+6, full 32 TDC-test channels per ASIC, 100 kHz, pulse-high 3 | `underfilled` | 16476 | 93740 | 0 | 0 | 0 |

For P6B020, the failing lower-pair full-channel case, lane 5 and lane 6 stayed
stable through the injection window:

| Lane | Go | Mode | Error counter before | Error counter after | DPA unlocks before | DPA unlocks after |
|---:|---:|---|---:|---:|---:|---:|
| 5 | 1 | adaptive | 1670 | 1670 | 0 | 0 |
| 6 | 1 | adaptive | 1670 | 1670 | 0 | 0 |

## Interpretation

The current lower-pair full-channel blocker is not explained by LVDS decode
errors or DPA unlocks in the active image. The failure reproduces as MTS/ring
timestamp-error propagation while LVDS counters are flat.

Do not spend the next compile on swapping the LVDS controller first. The next
debug target is MTS timestamp/epoch causality into the ring-buffer CAM input.
Use SignalTap or a focused MTS simulation to prove whether the bad beats enter
MTS with a wrong timestamp, acquire the wrong delay inside MTS, or are forwarded
to the ring with a correct error sideband from an expected negative condition.
