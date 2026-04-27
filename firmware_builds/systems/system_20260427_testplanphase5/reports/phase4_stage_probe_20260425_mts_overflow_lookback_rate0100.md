# Phase 4 Stage Counter Probe

- Timestamp: `2026-04-25T19:16:51`
- SC link: `2`
- FEB target: `7`
- Hit rate: `0x0100`
- Duration: `100 ms`
- Iterations: `2`
- Ring input-error filter override: `keep`
- MTS expected latency override: `None`

## Summary

| Iter | Class | Emu Frames | MTS Hits | Ring InErr | Ring Push | Ring Pop | Frame Actual | Hist Total | Hist Drop | CRC Err | Ingress | SC Flags | SC Drops |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | `PASS` | 113808 | 1417064 | 48 | 1417052 | 1417052 | 1417052 | 708829 | 0 | 0 | `0x00000403` | `0x00000000` | 0 |
| 1 | `PASS` | 114872 | 237248332 | 48 | 1430653 | 1430653 | 1430653 | 715721 | 0 | 0 | `0x00000E03` | `0x00000000` | 0 |

## Per-Iteration Stage Detail

### Iteration 0

- Classification: `PASS`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': None}`
- Ingress select status: `0x00000403`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 708831 | 708831 |
| `mts1.total_hits` | 0 | 708233 | 708233 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 2/177244/177244 | 2/177244/177244 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 2/176870/176870 | 2/176870/176870 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 2/178176/178176 | 2/178176/178176 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 2/176539/176539 | 2/176539/176539 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 10/176938/176938 | 10/176938/176938 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 10/178146/178146 | 10/178146/178146 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 10/174721/174721 | 10/174721/174721 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 10/178418/178418 | 10/178418/178418 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 708829/708829/0 | 708829/708829/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 708223/708223/0 | 708223/708223/0 |
| `hist.total/dropped` | 0/0 | 708829/0 | 708829/0 |

### Iteration 1

- Classification: `PASS`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': None}`
- Ingress select status: `0x00000403`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 715723 | 715723 |
| `mts1.total_hits` | 0 | 236532609 | 236532609 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 2/178880/178880 | 2/178880/178880 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 2/178606/178606 | 2/178606/178606 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 2/179928/179928 | 2/179928/179928 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 2/178307/178307 | 2/178307/178307 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 10/178654/178654 | 10/178654/178654 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 10/179798/179798 | 10/179798/179798 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 10/176334/176334 | 10/176334/176334 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 10/180146/180146 | 10/180146/180146 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 715721/715721/0 | 715721/715721/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 714932/714932/0 | 714932/714932/0 |
| `hist.total/dropped` | 0/0 | 715721/0 | 715721/0 |

