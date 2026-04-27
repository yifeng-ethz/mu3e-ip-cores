# Phase 4 Stage Counter Probe

- Timestamp: `2026-04-25T16:42:59`
- SC link: `2`
- FEB target: `7`
- Hit rate: `0x0800`
- Duration: `50 ms`
- Iterations: `1`
- Ring input-error filter override: `keep`
- MTS expected latency override: `4096`

## Summary

| Iter | Class | Emu Frames | MTS Hits | Ring InErr | Ring Push | Ring Pop | Frame Actual | Hist Total | Hist Drop | CRC Err | Ingress | SC Flags | SC Drops |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | `mixed_or_saturated` | 80808 | 5081909 | 0 | 5081909 | 5081909 | 5081909 | 2541276 | 11 | 0 | `0x00000603` | `0x00000000` | 0 |

## Per-Iteration Stage Detail

### Iteration 0

- Classification: `mixed_or_saturated`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': 4096}`
- Ingress select status: `0x00000403`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 2541276 | 2541276 |
| `mts1.total_hits` | 0 | 2540633 | 2540633 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 0/631586/631586 | 0/631586/631586 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 0/635941/635941 | 0/635941/635941 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 0/637989/637989 | 0/637989/637989 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 0/635760/635760 | 0/635760/635760 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 0/633438/633438 | 0/633438/633438 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 0/640093/640093 | 0/640093/640093 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 0/635025/635025 | 0/635025/635025 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 0/632077/632077 | 0/632077/632077 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 2541276/2541276/0 | 2541276/2541276/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 2540633/2540633/0 | 2540633/2540633/0 |
| `hist.total/dropped` | 0/0 | 2541276/11 | 2541276/11 |

