# Phase 4 Stage Counter Probe

- Timestamp: `2026-04-28T11:44:30`
- SC link: `2`
- FEB target: `7`
- Hit rate: `0x0800`
- Duration: `250 ms`
- Iterations: `1`
- Ring input-error filter override: `keep`
- MTS expected latency override: `None`
- MTS timestamp-delay local-drop override: `keep`

## Summary

| Iter | Class | Mux Selected | Emu Frames | MTS Hits | MTS Discard | Ring InErr | Ring Push | Ring Pop | Frame Actual | Hist Total | Hist Drop | CRC Err | Flush | Ingress | SC Flags | SC Drops |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|
| 0 | `mixed_or_saturated` | 3416572818 | 225476 | 99772988 | 0 | 3826494 | 111872943 | 111872726 | 125260516 | 30337764 | 2997 | 0 | `clean` | `0x00000603` | `0x00000048` | 0 |

## Per-Iteration Stage Detail

### Iteration 0

- Classification: `mixed_or_saturated`
- Lane-go: `0x000001FF`
- Source mux selected: `emulator` lanes 0..7; deltas real/emu/selected = `3416572818/3416572818/3416572818`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': None, 'mts_drop_delay_error': 'keep'}`
- Ingress select status: `0x00000403`
- Post-end flush: `clean` (PORT_STATUS=0x00FF00FF, COAL_STATUS=0x00000100)

| Stage | Before | Sample | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 49249801 | 49249801 |
| `mts0.discard_hits` | 0 | 0 | 0 |
| `mts1.total_hits` | 0 | 50523187 | 50523187 |
| `mts1.discard_hits` | 0 | 0 | 0 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 435940/12824517/12824480 | 435940/12824517/12824480 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 445483/13092729/13092688 | 445483/13092729/13092688 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 460080/13511934/13511911 | 460080/13511934/13511911 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 469509/13801620/13801613 | 469509/13801620/13801613 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 485752/14125623/14125571 | 485752/14125623/14125571 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 497025/14444148/14444112 | 497025/14444148/14444112 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 511340/14886263/14886247 | 511340/14886263/14886247 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 521365/15186109/15186104 | 521365/15186109/15186104 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 62024867/62024867/0 | 62024867/62024867/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 63235645/63235649/0 | 63235645/63235649/0 |
| `hist.total/dropped` | 0/0 | 30337764/2997 | 30337764/2997 |

