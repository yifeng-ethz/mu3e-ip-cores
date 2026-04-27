# Phase 4 Stage Counter Probe

- Timestamp: `2026-04-25T16:40:35`
- SC link: `2`
- FEB target: `7`
- Hit rate: `0x0800`
- Duration: `100 ms`
- Iterations: `1`
- Ring input-error filter override: `keep`
- MTS expected latency override: `None`

## Summary

| Iter | Class | Emu Frames | MTS Hits | Ring InErr | Ring Push | Ring Pop | Frame Actual | Hist Total | Hist Drop | CRC Err | Ingress | SC Flags | SC Drops |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | `blocked_mts_to_hitstack` | 114952 | 517324934 | 28916316 | 0 | 0 | 0 | 0 | 0 | 0 | `0x00000503` | `0x00000000` | 0 |

## Per-Iteration Stage Detail

### Iteration 0

- Classification: `blocked_mts_to_hitstack`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': None}`
- Ingress select status: `0x00000403`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 255187249 | 255187249 |
| `mts1.total_hits` | 0 | 262137685 | 262137685 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 3614919/0/0 | 3614919/0/0 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 3614919/0/0 | 3614919/0/0 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 3614919/0/0 | 3614919/0/0 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 3614919/0/0 | 3614919/0/0 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 3614160/0/0 | 3614160/0/0 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 3614160/0/0 | 3614160/0/0 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 3614160/0/0 | 3614160/0/0 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 3614160/0/0 | 3614160/0/0 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 0/0/0 | 0/0/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 0/0/0 | 0/0/0 |
| `hist.total/dropped` | 0/0 | 0/0 | 0/0 |

