# Phase 4 Stage Counter Probe

- Timestamp: `2026-04-28T11:45:06`
- SC link: `2`
- FEB target: `7`
- Hit rate: `0x0400`
- Duration: `250 ms`
- Iterations: `1`
- Ring input-error filter override: `keep`
- MTS expected latency override: `None`
- MTS timestamp-delay local-drop override: `keep`

## Summary

| Iter | Class | Mux Selected | Emu Frames | MTS Hits | MTS Discard | Ring InErr | Ring Push | Ring Pop | Frame Actual | Hist Total | Hist Drop | CRC Err | Flush | Ingress | SC Flags | SC Drops |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|
| 0 | `PASS` | 3309535494 | 222362 | 79945024 | 0 | 232109 | 90619437 | 90619238 | 99794875 | 18196610 | 0 | 0 | `clean` | `0x00000603` | `0x00000048` | 0 |

## Per-Iteration Stage Detail

### Iteration 0

- Classification: `PASS`
- Lane-go: `0x000001FF`
- Source mux selected: `emulator` lanes 0..7; deltas real/emu/selected = `3309535494/3309535494/3309535494`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': None, 'mts_drop_delay_error': 'keep'}`
- Ingress select status: `0x00000403`
- Post-end flush: `clean` (PORT_STATUS=0x00C900FF, COAL_STATUS=0x00000100)

| Stage | Before | Sample | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 39562968 | 39562968 |
| `mts0.discard_hits` | 0 | 0 | 0 |
| `mts1.total_hits` | 0 | 40382056 | 40382056 |
| `mts1.discard_hits` | 0 | 0 | 0 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 27108/10536425/10536406 | 27108/10536425/10536406 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 27653/10762250/10762234 | 27653/10762250/10762234 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 28253/11005579/11005555 | 28253/11005579/11005555 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 28777/11214878/11214858 | 28777/11214878/11214858 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 29304/11450823/11450793 | 29304/11450823/11450793 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 29817/11660749/11660721 | 29817/11660749/11660721 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 30323/11873361/11873322 | 30323/11873361/11873322 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 30874/12115372/12115349 | 30874/12115372/12115349 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 49473495/49473499/0 | 49473495/49473499/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 50321376/50321376/0 | 50321376/50321376/0 |
| `hist.total/dropped` | 0/0 | 18196610/0 | 18196610/0 |

