# Phase 4 Stage Counter Probe

- Timestamp: `2026-04-25T17:33:09`
- SC link: `2`
- FEB target: `7`
- Hit rate: `0x0800`
- Duration: `100 ms`
- Iterations: `1`
- Ring input-error filter override: `keep`
- MTS expected latency override: `65535`

## Summary

| Iter | Class | Emu Frames | MTS Hits | Ring InErr | Ring Push | Ring Pop | Frame Actual | Hist Total | Hist Drop | CRC Err | Ingress | SC Flags | SC Drops |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | `mixed_or_saturated` | 120848 | 7599919 | 116 | 7599890 | 7599890 | 7599890 | 3800297 | 25882 | 0 | `0x00000403` | `0x00000048` | 0 |

## Per-Iteration Stage Detail

### Iteration 0

- Classification: `mixed_or_saturated`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': 65535}`
- Ingress select status: `0x00000503`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 3800320 | 3800320 |
| `mts1.total_hits` | 0 | 3799599 | 3799599 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 23/952930/952930 | 23/952930/952930 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 23/943822/943822 | 23/943822/943822 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 23/946540/946540 | 23/946540/946540 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 23/957005/957005 | 23/957005/957005 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 6/946334/946334 | 6/946334/946334 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 6/942339/942339 | 6/942339/942339 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 6/955420/955420 | 6/955420/955420 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 6/955500/955500 | 6/955500/955500 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 3800297/3800297/0 | 3800297/3800297/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 3799593/3799593/0 | 3799593/3799593/0 |
| `hist.total/dropped` | 0/0 | 3800297/25882 | 3800297/25882 |

