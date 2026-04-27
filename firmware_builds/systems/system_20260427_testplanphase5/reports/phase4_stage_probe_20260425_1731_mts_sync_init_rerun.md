# Phase 4 Stage Counter Probe

- Timestamp: `2026-04-25T17:31:02`
- SC link: `2`
- FEB target: `7`
- Hit rate: `0x0800`
- Duration: `100 ms`
- Iterations: `2`
- Ring input-error filter override: `keep`
- MTS expected latency override: `None`

## Summary

| Iter | Class | Emu Frames | MTS Hits | Ring InErr | Ring Push | Ring Pop | Frame Actual | Hist Total | Hist Drop | CRC Err | Ingress | SC Flags | SC Drops |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | `PASS` | 115232 | 7246744 | 28944452 | 10631 | 10631 | 10631 | 5359 | 0 | 0 | `0x00000603` | `0x00000048` | 0 |
| 1 | `PASS` | 116120 | 7302576 | 29018924 | 47845 | 47845 | 47845 | 24028 | 0 | 0 | `0x00000403` | `0x00000048` | 0 |

## Per-Iteration Stage Detail

### Iteration 0

- Classification: `PASS`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': None}`
- Ingress select status: `0x00000503`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 3623744 | 3623744 |
| `mts1.total_hits` | 0 | 3623000 | 3623000 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 3618385/1184/1184 | 3618385/1184/1184 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 3618385/1386/1386 | 3618385/1386/1386 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 3618385/1417/1417 | 3618385/1417/1417 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 3618385/1372/1372 | 3618385/1372/1372 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 3617728/1233/1233 | 3617728/1233/1233 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 3617728/1053/1053 | 3617728/1053/1053 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 3617728/1530/1530 | 3617728/1530/1530 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 3617728/1456/1456 | 3617728/1456/1456 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 5359/5359/0 | 5359/5359/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 5272/5272/0 | 5272/5272/0 |
| `hist.total/dropped` | 0/0 | 5359/0 | 5359/0 |

### Iteration 1

- Classification: `PASS`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': None}`
- Ingress select status: `0x00000403`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 3651658 | 3651658 |
| `mts1.total_hits` | 0 | 3650918 | 3650918 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 3627630/5997/5997 | 3627630/5997/5997 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 3627630/6056/6056 | 3627630/6056/6056 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 3627630/6202/6202 | 3627630/6202/6202 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 3627630/5773/5773 | 3627630/5773/5773 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 3627101/6050/6050 | 3627101/6050/6050 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 3627101/5975/5975 | 3627101/5975/5975 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 3627101/5849/5849 | 3627101/5849/5849 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 3627101/5943/5943 | 3627101/5943/5943 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 24028/24028/0 | 24028/24028/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 23817/23817/0 | 23817/23817/0 |
| `hist.total/dropped` | 0/0 | 24028/0 | 24028/0 |

