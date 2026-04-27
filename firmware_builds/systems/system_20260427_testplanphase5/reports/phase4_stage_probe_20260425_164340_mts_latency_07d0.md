# Phase 4 Stage Counter Probe

- Timestamp: `2026-04-25T16:43:50`
- SC link: `2`
- FEB target: `7`
- Hit rate: `0x0800`
- Duration: `50 ms`
- Iterations: `1`
- Ring input-error filter override: `keep`
- MTS expected latency override: `2000`

## Summary

| Iter | Class | Emu Frames | MTS Hits | Ring InErr | Ring Push | Ring Pop | Frame Actual | Hist Total | Hist Drop | CRC Err | Ingress | SC Flags | SC Drops |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | `mixed_or_saturated` | 82736 | 5203151 | 0 | 5203151 | 5203151 | 5203151 | 2601861 | 10828 | 0 | `0x00000403` | `0x00000000` | 0 |

## Per-Iteration Stage Detail

### Iteration 0

- Classification: `mixed_or_saturated`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': 2000}`
- Ingress select status: `0x00000403`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 2601861 | 2601861 |
| `mts1.total_hits` | 0 | 2601290 | 2601290 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 0/645711/645711 | 0/645711/645711 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 0/654965/654965 | 0/654965/654965 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 0/651754/651754 | 0/651754/651754 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 0/649431/649431 | 0/649431/649431 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 0/651984/651984 | 0/651984/651984 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 0/655499/655499 | 0/655499/655499 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 0/646953/646953 | 0/646953/646953 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 0/646854/646854 | 0/646854/646854 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 2601861/2601861/0 | 2601861/2601861/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 2601290/2601290/0 | 2601290/2601290/0 |
| `hist.total/dropped` | 0/0 | 2601861/10828 | 2601861/10828 |

