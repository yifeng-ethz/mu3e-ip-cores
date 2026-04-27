# Phase 4 Stage Counter Probe

- Timestamp: `2026-04-25T20:11:09`
- SC link: `2`
- FEB target: `7`
- Hit rate: `0x0100`
- Duration: `100 ms`
- Iterations: `2`
- Ring input-error filter override: `keep`
- MTS expected latency override: `None`

## Summary

| Iter | Class | Emu Frames | MTS Hits | MTS Discard | Ring InErr | Ring Push | Ring Pop | Frame Actual | Hist Total | Hist Drop | CRC Err | Ingress | SC Flags | SC Drops |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | `PASS` | 120632 | 1502248 | 0 | 48 | 1502236 | 1502236 | 1502236 | 751392 | 0 | 0 | `0x00000403` | `0x00000000` | 0 |
| 1 | `PASS` | 117680 | 1465689 | 0 | 48 | 1465677 | 1465677 | 1465677 | 732721 | 0 | 0 | `0x00000403` | `0x00000000` | 0 |

## Per-Iteration Stage Detail

### Iteration 0

- Classification: `PASS`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': None}`
- Ingress select status: `0x00000603`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 751394 | 751394 |
| `mts0.discard_hits` | 0 | 0 | 0 |
| `mts1.total_hits` | 0 | 750854 | 750854 |
| `mts1.discard_hits` | 0 | 0 | 0 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 2/187898/187898 | 2/187898/187898 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 2/187412/187412 | 2/187412/187412 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 2/188881/188881 | 2/188881/188881 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 2/187201/187201 | 2/187201/187201 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 10/187426/187426 | 10/187426/187426 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 10/189073/189073 | 10/189073/189073 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 10/185191/185191 | 10/185191/185191 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 10/189154/189154 | 10/189154/189154 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 751392/751392/0 | 751392/751392/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 750844/750844/0 | 750844/750844/0 |
| `hist.total/dropped` | 0/0 | 751392/0 | 751392/0 |

### Iteration 1

- Classification: `PASS`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': None}`
- Ingress select status: `0x00000403`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 732723 | 732723 |
| `mts0.discard_hits` | 0 | 0 | 0 |
| `mts1.total_hits` | 0 | 732966 | 732966 |
| `mts1.discard_hits` | 0 | 0 | 0 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 2/183180/183180 | 2/183180/183180 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 2/182734/182734 | 2/182734/182734 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 2/184232/184232 | 2/184232/184232 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 2/182575/182575 | 2/182575/182575 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 10/183082/183082 | 10/183082/183082 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 10/184469/184469 | 10/184469/184469 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 10/180719/180719 | 10/180719/180719 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 10/184686/184686 | 10/184686/184686 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 732721/732721/0 | 732721/732721/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 732956/732956/0 | 732956/732956/0 |
| `hist.total/dropped` | 0/0 | 732721/0 | 732721/0 |

