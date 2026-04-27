# Phase 4 Stage Counter Probe

- Timestamp: `2026-04-25T16:42:33`
- SC link: `2`
- FEB target: `7`
- Hit rate: `0x0800`
- Duration: `100 ms`
- Iterations: `2`
- Ring input-error filter override: `keep`
- MTS expected latency override: `65535`

## Summary

| Iter | Class | Emu Frames | MTS Hits | Ring InErr | Ring Push | Ring Pop | Frame Actual | Hist Total | Hist Drop | CRC Err | Ingress | SC Flags | SC Drops |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | `mixed_or_saturated` | 115072 | 7236672 | 0 | 7236672 | 7236672 | 7236672 | 3618710 | 62446 | 0 | `0x00000403` | `0x00000000` | 0 |
| 1 | `blocked_hist_ingress_or_stats` | 116296 | 7313649 | 0 | 7313649 | 7313649 | 7313649 | 0 | 0 | 0 | `0x00000603` | `0x00000000` | 0 |

## Per-Iteration Stage Detail

### Iteration 0

- Classification: `mixed_or_saturated`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': 65535}`
- Ingress select status: `0x00000403`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 3618710 | 3618710 |
| `mts1.total_hits` | 0 | 3617962 | 3617962 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 0/901223/901223 | 0/901223/901223 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 0/908987/908987 | 0/908987/908987 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 0/907822/907822 | 0/907822/907822 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 0/900678/900678 | 0/900678/900678 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 0/907331/907331 | 0/907331/907331 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 0/909558/909558 | 0/909558/909558 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 0/902549/902549 | 0/902549/902549 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 0/898524/898524 | 0/898524/898524 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 3618710/3618710/0 | 3618710/3618710/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 3617962/3617962/0 | 3617962/3617962/0 |
| `hist.total/dropped` | 0/0 | 3618710/62446 | 3618710/62446 |

### Iteration 1

- Classification: `blocked_hist_ingress_or_stats`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': 65535}`
- Ingress select status: `0x00000403`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 3657190 | 3657190 |
| `mts1.total_hits` | 0 | 3656459 | 3656459 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 0/917590/917590 | 0/917590/917590 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 0/907317/907317 | 0/907317/907317 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 0/912704/912704 | 0/912704/912704 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 0/919579/919579 | 0/919579/919579 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 0/912194/912194 | 0/912194/912194 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 0/905879/905879 | 0/905879/905879 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 0/919582/919582 | 0/919582/919582 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 0/918804/918804 | 0/918804/918804 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 3657190/3657190/0 | 3657190/3657190/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 3656459/3656459/0 | 3656459/3656459/0 |
| `hist.total/dropped` | 0/0 | 0/0 | 0/0 |

