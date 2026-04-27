# Phase 4 Stage Counter Probe

- Timestamp: `2026-04-25T17:38:53`
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
| 0 | `mixed_or_saturated` | 67160 | 4223617 | 2352 | 4223029 | 4223029 | 4223029 | 2111731 | 315 | 0 | `0x00000E03` | `0x00000048` | 0 |

## Per-Iteration Stage Detail

### Iteration 0

- Classification: `mixed_or_saturated`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': None}`
- Ingress select status: `0x00000603`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 2112035 | 2112035 |
| `mts1.total_hits` | 0 | 2111582 | 2111582 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 304/532678/532678 | 304/532678/532678 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 304/528174/528174 | 304/528174/528174 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 304/524356/524356 | 304/524356/524356 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 304/526523/526523 | 304/526523/526523 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 284/532435/532435 | 284/532435/532435 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 284/525594/525594 | 284/525594/525594 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 284/522227/522227 | 284/522227/522227 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 284/531042/531042 | 284/531042/531042 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 2111731/2111731/0 | 2111731/2111731/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 2111298/2111298/0 | 2111298/2111298/0 |
| `hist.total/dropped` | 0/0 | 2111731/315 | 2111731/315 |

