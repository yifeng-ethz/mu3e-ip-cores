# Phase 4 Stage Counter Probe

- Timestamp: `2026-04-25T16:43:33`
- SC link: `2`
- FEB target: `7`
- Hit rate: `0x0800`
- Duration: `50 ms`
- Iterations: `1`
- Ring input-error filter override: `keep`
- MTS expected latency override: `2001`

## Summary

| Iter | Class | Emu Frames | MTS Hits | Ring InErr | Ring Push | Ring Pop | Frame Actual | Hist Total | Hist Drop | CRC Err | Ingress | SC Flags | SC Drops |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | `mixed_or_saturated` | 82792 | 5206679 | 0 | 5206679 | 5206679 | 5206679 | 2603625 | 6017 | 0 | `0x00000603` | `0x00000000` | 0 |

## Per-Iteration Stage Detail

### Iteration 0

- Classification: `mixed_or_saturated`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': 2001}`
- Ingress select status: `0x00000403`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 2603625 | 2603625 |
| `mts1.total_hits` | 0 | 2603054 | 2603054 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 0/650288/650288 | 0/650288/650288 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 0/654969/654969 | 0/654969/654969 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 0/651552/651552 | 0/651552/651552 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 0/646816/646816 | 0/646816/646816 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 0/656369/656369 | 0/656369/656369 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 0/652105/652105 | 0/652105/652105 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 0/646995/646995 | 0/646995/646995 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 0/647585/647585 | 0/647585/647585 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 2603625/2603625/0 | 2603625/2603625/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 2603054/2603054/0 | 2603054/2603054/0 |
| `hist.total/dropped` | 0/0 | 2603625/6017 | 2603625/6017 |

