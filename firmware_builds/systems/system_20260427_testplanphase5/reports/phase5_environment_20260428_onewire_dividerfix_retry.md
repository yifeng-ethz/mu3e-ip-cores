# Phase-5 environmental monitor gate - OneWire divider-fix image

**Date:** 2026-04-28 20:04 CEST
**Image:** `top_stp_pipe_phase5_frame_hist`
**JSON evidence:** `phase5_environment_20260428_onewire_dividerfix_retry.json`

## Summary

| Result | Count |
|---|---:|
| PASS | 62 |
| WARN | 1 |
| FAIL | 0 |

The environmental gate passes on the divider-fix SOF. The monitor script first
tries quiet `sc_tool` transactions and retries with verbose `sc_tool` when the
quiet read path loses the valid packet in secondary-ring traffic; every final
environmental block read returned `rsp OK`.

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
| 0 | 29.688 |
| 1 | 33.125 |
| 2 | 21.500 |
| 3 | 21.938 |
| 4 | 39.875 |
| 5 | 39.875 |

All six OneWire lines were explicitly selected with `processor_go=1` and then
read back with `sample_valid=1`. The previous stale/default `1.0 C` signature is
not present.

## Other Monitors

| Monitor | Value | Result |
|---|---|---|
| MAX10 ID | `0x4D312850` | PASS |
| MAX10 version | `0x00020000` | PASS |
| MAX10 busy/fault | `0/0` | PASS |
| Firefly 1 temperature | `57 C` | PASS |
| Firefly 1 VCC raw | `57` | WARN |
| Firefly 1 RX powers | `3890, 3890, 2910, 2910` | PASS |
| Firefly 2 | temp `0`, VCC `0xFFFF`, RX powers all `0xFFFF` | PASS, expected absent |
| On-die temperature | `48 C` | PASS |
| Legacy Firefly bridge | reachable | PASS |

The lone warning is the existing Firefly 1 VCC raw-code sanity threshold. Optical
power values and module temperature are live, so this warning is recorded as a
monitor-scaling interpretation issue rather than a Phase-5 blocker.
