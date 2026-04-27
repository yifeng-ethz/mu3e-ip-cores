# Phase 4 Stage Counter Probe

- Timestamp: `2026-04-25T16:43:14`
- SC link: `2`
- FEB target: `7`
- Hit rate: `0x0800`
- Duration: `50 ms`
- Iterations: `1`
- Ring input-error filter override: `keep`
- MTS expected latency override: `2048`

## Summary

| Iter | Class | Emu Frames | MTS Hits | Ring InErr | Ring Push | Ring Pop | Frame Actual | Hist Total | Hist Drop | CRC Err | Ingress | SC Flags | SC Drops |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | `mixed_or_saturated` | 80728 | 5076875 | 0 | 5076875 | 5076875 | 5076875 | 2538756 | 37509 | 0 | `0x00000603` | `0x00000000` | 0 |

## Per-Iteration Stage Detail

### Iteration 0

- Classification: `mixed_or_saturated`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': 2048}`
- Ingress select status: `0x00000403`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 2538756 | 2538756 |
| `mts1.total_hits` | 0 | 2538119 | 2538119 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 0/634600/634600 | 0/634600/634600 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 0/638448/638448 | 0/638448/638448 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 0/637179/637179 | 0/637179/637179 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 0/628529/628529 | 0/628529/628529 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 0/636755/636755 | 0/636755/636755 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 0/636823/636823 | 0/636823/636823 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 0/635297/635297 | 0/635297/635297 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 0/629244/629244 | 0/629244/629244 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 2538756/2538756/0 | 2538756/2538756/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 2538119/2538119/0 | 2538119/2538119/0 |
| `hist.total/dropped` | 0/0 | 2538756/37509 | 2538756/37509 |

