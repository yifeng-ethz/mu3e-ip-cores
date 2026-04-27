# Phase 4 Stage Counter Probe

- Timestamp: `2026-04-25T20:11:47`
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
| 0 | `mixed_or_saturated` | 115048 | 7235167 | 0 | 22228 | 7229610 | 7229610 | 7229610 | 3615133 | 445 | 0 | `0x00000403` | `0x00000000` | 0 |
| 1 | `mixed_or_saturated` | 116072 | 7299122 | 0 | 22432 | 7293514 | 7293514 | 7293514 | 3647081 | 453 | 0 | `0x00000503` | `0x00000000` | 0 |

## Per-Iteration Stage Detail

### Iteration 0

- Classification: `mixed_or_saturated`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': None}`
- Ingress select status: `0x00000403`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 3617961 | 3617961 |
| `mts0.discard_hits` | 0 | 0 | 0 |
| `mts1.total_hits` | 0 | 3617206 | 3617206 |
| `mts1.discard_hits` | 0 | 0 | 0 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 2828/909760/909760 | 2828/909760/909760 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 2828/905995/905995 | 2828/905995/905995 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 2828/899669/899669 | 2828/899669/899669 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 2828/899709/899709 | 2828/899709/899709 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 2729/910981/910981 | 2729/910981/910981 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 2729/901223/901223 | 2729/901223/901223 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 2729/895806/895806 | 2729/895806/895806 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 2729/906467/906467 | 2729/906467/906467 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 3615133/3615133/0 | 3615133/3615133/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 3614477/3614477/0 | 3614477/3614477/0 |
| `hist.total/dropped` | 0/0 | 3615133/445 | 3615133/445 |

### Iteration 1

- Classification: `mixed_or_saturated`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': None}`
- Ingress select status: `0x00000403`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 3649928 | 3649928 |
| `mts0.discard_hits` | 0 | 0 | 0 |
| `mts1.total_hits` | 0 | 3649194 | 3649194 |
| `mts1.discard_hits` | 0 | 0 | 0 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 2847/918009/918009 | 2847/918009/918009 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 2847/913738/913738 | 2847/913738/913738 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 2847/907727/907727 | 2847/907727/907727 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 2847/907607/907607 | 2847/907607/907607 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 2761/919386/919386 | 2761/919386/919386 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 2761/909022/909022 | 2761/909022/909022 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 2761/903253/903253 | 2761/903253/903253 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 2761/914772/914772 | 2761/914772/914772 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 3647081/3647081/0 | 3647081/3647081/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 3646433/3646433/0 | 3646433/3646433/0 |
| `hist.total/dropped` | 0/0 | 3647081/453 | 3647081/453 |

