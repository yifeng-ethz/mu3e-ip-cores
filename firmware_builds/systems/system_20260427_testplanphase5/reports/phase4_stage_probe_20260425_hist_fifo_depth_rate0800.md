# Phase 4 Stage Counter Probe

- Timestamp: `2026-04-25T21:15:26`
- SC link: `2`
- FEB target: `7`
- Hit rate: `0x0800`
- Duration: `100 ms`
- Iterations: `2`
- Ring input-error filter override: `keep`
- MTS expected latency override: `None`

## Summary

| Iter | Class | Emu Frames | MTS Hits | MTS Discard | Ring InErr | Ring Push | Ring Pop | Frame Actual | Hist Total | Hist Drop | CRC Err | Ingress | SC Flags | SC Drops |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | `blocked_hist_ingress_or_stats` | 120752 | 7593649 | 0 | 23332 | 7587816 | 7587816 | 7587816 | 0 | 0 | 0 | `0x00000703` | `0x00000000` | 0 |
| 1 | `blocked_hist_ingress_or_stats` | 117616 | 7396624 | 0 | 22696 | 7390950 | 7390950 | 7390950 | 0 | 0 | 0 | `0x00000603` | `0x00000000` | 0 |

## Per-Iteration Stage Detail

### Iteration 0

- Classification: `blocked_hist_ingress_or_stats`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': None}`
- Ingress select status: `0x00000703`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 3797184 | 3797184 |
| `mts0.discard_hits` | 0 | 0 | 0 |
| `mts1.total_hits` | 0 | 3796465 | 3796465 |
| `mts1.discard_hits` | 0 | 0 | 0 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 2957/954927/954927 | 2957/954927/954927 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 2957/950236/950236 | 2957/950236/950236 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 2957/944528/944528 | 2957/944528/944528 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 2957/944536/944536 | 2957/944536/944536 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 2876/956471/956471 | 2876/956471/956471 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 2876/946131/946131 | 2876/946131/946131 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 2876/939788/939788 | 2876/939788/939788 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 2876/951199/951199 | 2876/951199/951199 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 3794227/3794227/0 | 3794227/3794227/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 3793589/3793589/0 | 3793589/3793589/0 |
| `hist.total/dropped` | 0/0 | 0/0 | 0/0 |

### Iteration 1

- Classification: `blocked_hist_ingress_or_stats`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': None}`
- Ingress select status: `0x00000503`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 3698695 | 3698695 |
| `mts0.discard_hits` | 0 | 0 | 0 |
| `mts1.total_hits` | 0 | 3697929 | 3697929 |
| `mts1.discard_hits` | 0 | 0 | 0 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 2880/930319/930319 | 2880/930319/930319 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 2880/925937/925937 | 2880/925937/925937 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 2880/919924/919924 | 2880/919924/919924 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 2880/919635/919635 | 2880/919635/919635 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 2794/931778/931778 | 2794/931778/931778 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 2794/921381/921381 | 2794/921381/921381 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 2794/915033/915033 | 2794/915033/915033 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 2794/926943/926943 | 2794/926943/926943 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 3695815/3695815/0 | 3695815/3695815/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 3695135/3695135/0 | 3695135/3695135/0 |
| `hist.total/dropped` | 0/0 | 0/0 | 0/0 |

