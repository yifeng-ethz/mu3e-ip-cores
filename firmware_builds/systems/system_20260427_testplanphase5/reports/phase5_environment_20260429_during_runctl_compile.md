# Phase-5 Environmental Monitor Gate - 2026-04-29

**Image:** currently programmed Phase-5 frame/MTS/histogram debug image
**JSON evidence:** `phase5_environment_20260429_during_runctl_compile.json`

## Summary

| Result | Count |
|---|---:|
| PASS | 62 |
| WARN | 1 |
| FAIL | 0 |

The environmental gate passes after explicitly starting the upgraded OneWire
monitor loop on each synthesized DQ line. The previous stale/default `1.0 C`
signature is not present.

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
| 0 | 30.188 |
| 1 | 32.875 |
| 2 | 21.562 |
| 3 | 21.938 |
| 4 | 39.812 |
| 5 | 39.500 |

All six per-line status readbacks echoed the selected line, kept
`processor_go=1`, and reported `sample_valid=1` with clear CRC/init flags.

## Other Monitors

| Monitor | Value | Result |
|---|---|---|
| Firefly 2 | temp `0`, VCC `0xFFFF`, RX powers all `0xFFFF` | PASS, expected absent |
| Firefly 1 VCC raw | `57` | WARN |

The lone warning is the existing Firefly 1 VCC raw-code scaling interpretation.
Firefly 1 temperature and RX optical powers are live in the JSON evidence, so
this warning remains non-blocking for Phase 5.
