# Phase 4 Stage Counter Probe

- Timestamp: `2026-04-25T17:32:24`
- SC link: `2`
- FEB target: `7`
- Hit rate: `0x0800`
- Duration: `100 ms`
- Iterations: `2`
- Ring input-error filter override: `keep`
- MTS expected latency override: `2000`

## Summary

| Iter | Class | Emu Frames | MTS Hits | Ring InErr | Ring Push | Ring Pop | Frame Actual | Hist Total | Hist Drop | CRC Err | Ingress | SC Flags | SC Drops |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | `PASS` | 114304 | 7188388 | 28706816 | 11684 | 11684 | 11684 | 5848 | 0 | 0 | `0x00000403` | `0x00000048` | 0 |
| 1 | `blocked_mts_to_hitstack` | 113792 | 481512625 | 28622868 | 0 | 0 | 0 | 0 | 0 | 0 | `0x00000703` | `0x00000048` | 0 |

## Per-Iteration Stage Detail

### Iteration 0

- Classification: `PASS`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': 2000}`
- Ingress select status: `0x00000403`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 3594604 | 3594604 |
| `mts1.total_hits` | 0 | 3593784 | 3593784 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 3588756/1536/1536 | 3588756/1536/1536 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 3588756/1512/1512 | 3588756/1512/1512 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 3588756/1419/1419 | 3588756/1419/1419 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 3588756/1381/1381 | 3588756/1381/1381 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 3587948/1535/1535 | 3587948/1535/1535 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 3587948/1436/1436 | 3587948/1436/1436 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 3587948/1378/1378 | 3587948/1378/1378 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 3587948/1487/1487 | 3587948/1487/1487 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 5848/5848/0 | 5848/5848/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 5836/5836/0 | 5836/5836/0 |
| `hist.total/dropped` | 0/0 | 5848/0 | 5848/0 |

### Iteration 1

- Classification: `blocked_mts_to_hitstack`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': 2000}`
- Ingress select status: `0x00000E03`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 237213928 | 237213928 |
| `mts1.total_hits` | 0 | 244298697 | 244298697 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 3578248/0/0 | 3578248/0/0 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 3578248/0/0 | 3578248/0/0 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 3578248/0/0 | 3578248/0/0 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 3578248/0/0 | 3578248/0/0 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 3577469/0/0 | 3577469/0/0 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 3577469/0/0 | 3577469/0/0 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 3577469/0/0 | 3577469/0/0 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 3577469/0/0 | 3577469/0/0 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 0/0/0 | 0/0/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 0/0/0 | 0/0/0 |
| `hist.total/dropped` | 0/0 | 0/0 | 0/0 |

