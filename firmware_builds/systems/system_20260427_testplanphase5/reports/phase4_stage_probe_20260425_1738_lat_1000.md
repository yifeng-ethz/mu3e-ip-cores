# Phase 4 Stage Counter Probe

- Timestamp: `2026-04-25T17:34:01`
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
| 0 | `blocked_hist_ingress_or_stats` | 84144 | 532803716 | 584472 | 5145460 | 5145460 | 5145460 | 0 | 0 | 0 | `0x00000503` | `0x00000048` | 0 |

## Per-Iteration Stage Detail

### Iteration 0

- Classification: `blocked_hist_ingress_or_stats`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': 4096}`
- Ingress select status: `0x00000403`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 262202371 | 262202371 |
| `mts1.total_hits` | 0 | 270601345 | 270601345 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 74215/641680/641680 | 74215/641680/641680 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 74215/646332/646332 | 74215/646332/646332 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 74215/643796/643796 | 74215/643796/643796 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 74215/640067/640067 | 74215/640067/640067 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 71903/648412/648412 | 71903/648412/648412 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 71903/644410/644410 | 71903/644410/644410 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 71903/639720/639720 | 71903/639720/639720 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 71903/641043/641043 | 71903/641043/641043 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 2571875/2571875/0 | 2571875/2571875/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 2573585/2573585/0 | 2573585/2573585/0 |
| `hist.total/dropped` | 0/0 | 0/0 | 0/0 |

