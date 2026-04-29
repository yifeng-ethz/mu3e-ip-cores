# Phase-5 Environmental Monitor Gate - 2026-04-29 Runctl/MTS Stage Image

**Image:** `top_stp_pipe_runctl_mts_stage.sof`, programmed 2026-04-29 10:09:44.
**SOF checksum:** `0x145AA92C`.
**JSON evidence:** `phase5_environment_20260429_runctl_mts_stage.json`.

## Summary

| Result | Count |
|---|---:|
| PASS | 62 |
| WARN | 1 |
| FAIL | 0 |

The environmental gate passes on the freshly programmed runctl/MTS-stage
SignalTap image. The OneWire monitor loop is active and the old stale/default
`1.0 C` signature is not present.

## OneWire

| Check | Value |
|---|---:|
| UID | `0x4F574D43` |
| DQ lines | 6 |
| `STATUS[24] crc_err` | 0 |
| `STATUS[25] init_err` | 0 |
| `STATUS[26] sample_valid` | 1 |

| Sensor | Temperature C |
|---|---:|
| 0 | 29.938 |
| 1 | 33.250 |
| 2 | 21.625 |
| 3 | 22.000 |
| 4 | 40.375 |
| 5 | 40.188 |

All six per-line status readbacks echoed the selected line, kept
`processor_go=1`, and reported `sample_valid=1` with clear CRC/init flags.

## Other Monitors

| Monitor | Value | Result |
|---|---|---|
| Firefly 1 temperature | `57` | PASS |
| Firefly 1 VCC raw | `57` | WARN |
| Firefly 1 RX optical powers raw | `3900`, `3900`, `2870`, `2870` | PASS |
| Firefly 2 | temp `0`, VCC `0xFFFF`, RX powers all `0xFFFF` | PASS, expected absent |

The lone warning is the existing Firefly 1 VCC raw-code scaling interpretation.
Firefly 2 remains correctly classified as dangling for this Phase-5 setup.
