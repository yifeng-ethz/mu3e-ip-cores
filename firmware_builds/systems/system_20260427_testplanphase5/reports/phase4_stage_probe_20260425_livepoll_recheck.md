# Phase 4 Stage Counter Probe

- Timestamp: `2026-04-25T16:33:18`
- SC link: `2`
- FEB target: `7`
- Hit rate: `0x0800`
- Duration: `100 ms`
- Iterations: `1`

## Summary

| Iter | Class | Emu Frames | MTS Hits | Ring Push | Ring Pop | Frame Actual | Hist Total | Hist Drop | CRC Err | Ingress | SC Flags | SC Drops |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | `blocked_mts_to_hitstack` | 124832 | 7850440 | 0 | 0 | 0 | 0 | 0 | 0 | `0x00000403` | `0x00000000` | 0 |

## Per-Iteration Stage Detail

### Iteration 0

- Classification: `blocked_mts_to_hitstack`
- Lane-go: `0x000001FF`
- Ingress select status: `0x00000403`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 3925661 | 3925661 |
| `mts1.total_hits` | 0 | 3924779 | 3924779 |
| `hs0_rb0.push/pop` | 0/0 | 0/0 | 0/0 |
| `hs0_rb1.push/pop` | 0/0 | 0/0 | 0/0 |
| `hs0_rb2.push/pop` | 0/0 | 0/0 | 0/0 |
| `hs0_rb3.push/pop` | 0/0 | 0/0 | 0/0 |
| `hs1_rb0.push/pop` | 0/0 | 0/0 | 0/0 |
| `hs1_rb1.push/pop` | 0/0 | 0/0 | 0/0 |
| `hs1_rb2.push/pop` | 0/0 | 0/0 | 0/0 |
| `hs1_rb3.push/pop` | 0/0 | 0/0 | 0/0 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 0/0/0 | 0/0/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 0/0/0 | 0/0/0 |
| `hist.total/dropped` | 0/0 | 0/0 | 0/0 |

