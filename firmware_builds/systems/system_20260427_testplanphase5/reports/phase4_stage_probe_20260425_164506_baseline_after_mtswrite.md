# Phase 4 Stage Counter Probe

- Timestamp: `2026-04-25T16:45:15`
- SC link: `2`
- FEB target: `7`
- Hit rate: `0x0800`
- Duration: `50 ms`
- Iterations: `1`
- Ring input-error filter override: `keep`
- MTS expected latency override: `None`

## Summary

| Iter | Class | Emu Frames | MTS Hits | Ring InErr | Ring Push | Ring Pop | Frame Actual | Hist Total | Hist Drop | CRC Err | Ingress | SC Flags | SC Drops |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | `mixed_or_saturated` | 82728 | 5202647 | 0 | 5202647 | 5202647 | 5202647 | 2601609 | 186 | 0 | `0x00000403` | `0x00000000` | 0 |

## Per-Iteration Stage Detail

### Iteration 0

- Classification: `mixed_or_saturated`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': None}`
- Ingress select status: `0x00000403`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 2601609 | 2601609 |
| `mts1.total_hits` | 0 | 2601038 | 2601038 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 0/647505/647505 | 0/647505/647505 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 0/656407/656407 | 0/656407/656407 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 0/651777/651777 | 0/651777/651777 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 0/645920/645920 | 0/645920/645920 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 0/653673/653673 | 0/653673/653673 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 0/654720/654720 | 0/654720/654720 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 0/647929/647929 | 0/647929/647929 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 0/644716/644716 | 0/644716/644716 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 2601609/2601609/0 | 2601609/2601609/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 2601038/2601038/0 | 2601038/2601038/0 |
| `hist.total/dropped` | 0/0 | 2601609/186 | 2601609/186 |

