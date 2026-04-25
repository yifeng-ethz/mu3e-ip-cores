# Phase 4 Stage Counter Probe

- Timestamp: `2026-04-25T21:20:08`
- SC link: `2`
- FEB target: `7`
- Hit rate: `0x0800`
- Duration: `100 ms`
- Iterations: `2`
- Ring input-error filter override: `keep`
- MTS expected latency override: `None`

## Summary

| Iter | Class | Emu Frames | MTS Hits | MTS Discard | Ring InErr | Ring Push | Ring Pop | Frame Actual | Hist Total | Hist Drop | CRC Err | Flush | Ingress | SC Flags | SC Drops |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|
| 0 | `PASS` | 179933 | 71519429 | 0 | 257065 | 83441992 | 83441718 | 95010808 | 49247643 | 0 | 0 | `clean` | `0x00000603` | `0x00000000` | 0 |
| 1 | `PASS` | 161581 | 70854857 | 0 | 254946 | 82759510 | 82759059 | 94776715 | 49209095 | 0 | 0 | `clean` | `0x00000403` | `0x00000000` | 0 |

## Per-Iteration Stage Detail

### Iteration 0

- Classification: `PASS`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': None}`
- Ingress select status: `0x00000403`
- Post-end flush: `clean` (PORT_STATUS=0x00FF00FF, COAL_STATUS=0x00000100)

| Stage | Before | Sample | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 35090118 | 35090118 |
| `mts0.discard_hits` | 0 | 0 | 0 |
| `mts1.total_hits` | 0 | 36429311 | 36429311 |
| `mts1.discard_hits` | 0 | 0 | 0 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 29158/9419944/9419876 | 29158/9419944/9419876 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 30068/9700541/9700502 | 30068/9700541/9700502 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 30939/9987964/9987933 | 30939/9987964/9987933 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 31844/10284541/10284498 | 31844/10284541/10284498 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 32412/10578376/10578333 | 32412/10578376/10578333 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 33302/10868214/10868200 | 33302/10868214/10868200 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 34211/11159848/11159842 | 34211/11159848/11159842 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 35131/11442564/11442534 | 35131/11442564/11442534 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 46903545/46903540/0 | 46903545/46903540/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 48107267/48107268/0 | 48107267/48107268/0 |
| `hist.total/dropped` | 0/0 | 49247643/0 | 49247643/0 |

### Iteration 1

- Classification: `PASS`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': None}`
- Ingress select status: `0x00000403`
- Post-end flush: `clean` (PORT_STATUS=0x00FF00FF, COAL_STATUS=0x00000100)

| Stage | Before | Sample | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 34850169 | 34850169 |
| `mts0.discard_hits` | 0 | 0 | 0 |
| `mts1.total_hits` | 0 | 36004688 | 36004688 |
| `mts1.discard_hits` | 0 | 0 | 0 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 28767/9293687/9293602 | 28767/9293687/9293602 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 29699/9578665/9578600 | 29699/9578665/9578600 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 30678/9903943/9903879 | 30678/9903943/9903879 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 31608/10210832/10210792 | 31608/10210832/10210792 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 32146/10490167/10490125 | 32146/10490167/10490125 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 33084/10796655/10796605 | 33084/10796655/10796605 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 34001/11093610/11093562 | 34001/11093610/11093562 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 34963/11391951/11391894 | 34963/11391951/11391894 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 46769905/46769906/0 | 46769905/46769906/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 48006808/48006809/0 | 48006808/48006809/0 |
| `hist.total/dropped` | 0/0 | 49209095/0 | 49209095/0 |

