# Phase 4 Stage Counter Probe

- Timestamp: `2026-04-25T16:27:16`
- SC link: `2`
- FEB target: `7`
- Hit rate: `0x0800`
- Duration: `100 ms`
- Iterations: `1`

## Summary

| Iter | Class | Emu Frames | MTS Hits | Ring Push | Ring Pop | Frame Actual | Hist Total | Hist Drop | CRC Err | Ingress | SC Flags | SC Drops |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | `blocked_hist_ingress_or_stats` | 116096 | 498362262 | 2132590 | 2132590 | 2132590 | 0 | 0 | 0 | `0x00000503` | `0x00000000` | 0 |

## Per-Iteration Stage Detail

### Iteration 0

- Classification: `blocked_hist_ingress_or_stats`
- Lane-go: `0x000001FF`
- Ingress select status: `0x00000503`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 245506334 | 245506334 |
| `mts1.total_hits` | 0 | 252855928 | 252855928 |
| `hs0_rb0.push/pop` | 0/0 | 261387/261387 | 261387/261387 |
| `hs0_rb1.push/pop` | 0/0 | 267943/267943 | 267943/267943 |
| `hs0_rb2.push/pop` | 0/0 | 264756/264756 | 264756/264756 |
| `hs0_rb3.push/pop` | 0/0 | 266838/266838 | 266838/266838 |
| `hs1_rb0.push/pop` | 0/0 | 266607/266607 | 266607/266607 |
| `hs1_rb1.push/pop` | 0/0 | 271180/271180 | 271180/271180 |
| `hs1_rb2.push/pop` | 0/0 | 269659/269659 | 269659/269659 |
| `hs1_rb3.push/pop` | 0/0 | 264220/264220 | 264220/264220 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 1060924/1060924/0 | 1060924/1060924/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 1071666/1071666/0 | 1071666/1071666/0 |
| `hist.total/dropped` | 0/0 | 0/0 | 0/0 |

