# Phase 4 Stage Counter Probe

- Timestamp: `2026-04-25T17:30:13`
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
| 0 | `blocked_mts_to_hitstack` | 119424 | 7510360 | 30041440 | 0 | 0 | 0 | 0 | 0 | 0 | `0x00000403` | `0x00000048` | 0 |
| 1 | `mixed_or_saturated` | 116736 | 483453292 | 316004 | 7261887 | 7261887 | 7261887 | 3631458 | 170 | 0 | `0x00000503` | `0x00000048` | 0 |

## Per-Iteration Stage Detail

### Iteration 0

- Classification: `blocked_mts_to_hitstack`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': None}`
- Ingress select status: `0x00000C03`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 3755528 | 3755528 |
| `mts1.total_hits` | 0 | 3754832 | 3754832 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 3755528/0/0 | 3755528/0/0 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 3755528/0/0 | 3755528/0/0 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 3755528/0/0 | 3755528/0/0 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 3755528/0/0 | 3755528/0/0 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 3754832/0/0 | 3754832/0/0 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 3754832/0/0 | 3754832/0/0 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 3754832/0/0 | 3754832/0/0 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 3754832/0/0 | 3754832/0/0 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 0/0/0 | 0/0/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 0/0/0 | 0/0/0 |
| `hist.total/dropped` | 0/0 | 0/0 | 0/0 |

### Iteration 1

- Classification: `mixed_or_saturated`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': None}`
- Ingress select status: `0x00000E03`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 238201986 | 238201986 |
| `mts1.total_hits` | 0 | 245251306 | 245251306 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 39372/902899/902899 | 39372/902899/902899 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 39372/907168/907168 | 39372/907168/907168 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 39372/914076/914076 | 39372/914076/914076 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 39372/907315/907315 | 39372/907315/907315 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 39629/902244/902244 | 39629/902244/902244 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 39629/914569/914569 | 39629/914569/914569 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 39629/910452/910452 | 39629/910452/910452 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 39629/903164/903164 | 39629/903164/903164 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 3631458/3631458/0 | 3631458/3631458/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 3630429/3630429/0 | 3630429/3630429/0 |
| `hist.total/dropped` | 0/0 | 3631458/170 | 3631458/170 |

