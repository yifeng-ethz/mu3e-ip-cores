# Phase 4 Stage Counter Probe

- Timestamp: `2026-04-25T19:16:10`
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
| 0 | `mixed_or_saturated` | 114472 | 7198944 | 22128 | 7193412 | 7193412 | 7193412 | 3597054 | 436 | 0 | `0x00000403` | `0x00000000` | 0 |
| 1 | `mixed_or_saturated` | 113936 | 7165236 | 22048 | 7159724 | 7159724 | 7159724 | 3580211 | 436 | 0 | `0x00000403` | `0x00000000` | 0 |

## Per-Iteration Stage Detail

### Iteration 0

- Classification: `mixed_or_saturated`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': None}`
- Ingress select status: `0x00000403`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 3599870 | 3599870 |
| `mts1.total_hits` | 0 | 3599074 | 3599074 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 2816/905320/905320 | 2816/905320/905320 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 2816/901171/901171 | 2816/901171/901171 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 2816/895244/895244 | 2816/895244/895244 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 2816/895319/895319 | 2816/895319/895319 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 2716/906429/906429 | 2716/906429/906429 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 2716/896619/896619 | 2716/896619/896619 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 2716/891356/891356 | 2716/891356/891356 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 2716/901954/901954 | 2716/901954/901954 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 3597054/3597054/0 | 3597054/3597054/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 3596358/3596358/0 | 3596358/3596358/0 |
| `hist.total/dropped` | 0/0 | 3597054/436 | 3597054/436 |

### Iteration 1

- Classification: `mixed_or_saturated`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': None}`
- Ingress select status: `0x00000403`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 3583016 | 3583016 |
| `mts1.total_hits` | 0 | 3582220 | 3582220 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 2805/901102/901102 | 2805/901102/901102 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 2805/896867/896867 | 2805/896867/896867 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 2805/891153/891153 | 2805/891153/891153 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 2805/891089/891089 | 2805/891089/891089 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 2707/902098/902098 | 2707/902098/902098 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 2707/892563/892563 | 2707/892563/892563 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 2707/887275/887275 | 2707/887275/887275 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 2707/897577/897577 | 2707/897577/897577 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 3580211/3580211/0 | 3580211/3580211/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 3579513/3579513/0 | 3579513/3579513/0 |
| `hist.total/dropped` | 0/0 | 3580211/436 | 3580211/436 |

