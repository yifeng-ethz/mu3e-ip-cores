# Phase 4 Stage Counter Probe

- Timestamp: `2026-04-25T16:41:06`
- SC link: `2`
- FEB target: `7`
- Hit rate: `0x0800`
- Duration: `100 ms`
- Iterations: `2`
- Ring input-error filter override: `off`
- MTS expected latency override: `None`

## Summary

| Iter | Class | Emu Frames | MTS Hits | Ring InErr | Ring Push | Ring Pop | Frame Actual | Hist Total | Hist Drop | CRC Err | Ingress | SC Flags | SC Drops |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | `blocked_hist_ingress_or_stats` | 114144 | 7178310 | 0 | 7178310 | 7178310 | 7178310 | 0 | 0 | 0 | `0x00000603` | `0x00000000` | 0 |
| 1 | `blocked_hist_ingress_or_stats` | 118240 | 7435867 | 0 | 7435867 | 7435867 | 7435867 | 0 | 0 | 0 | `0x00000603` | `0x00000000` | 0 |

## Per-Iteration Stage Detail

### Iteration 0

- Classification: `blocked_hist_ingress_or_stats`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'off', 'mts_expected_latency': None, 'ring_ctrl_written': 1}`
- Ingress select status: `0x00000503`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 3589566 | 3589566 |
| `mts1.total_hits` | 0 | 3588744 | 3588744 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 0/891894/891894 | 0/891894/891894 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 0/894339/894339 | 0/894339/894339 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 0/905894/905894 | 0/905894/905894 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 0/897439/897439 | 0/897439/897439 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 0/889576/889576 | 0/889576/889576 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 0/901858/901858 | 0/901858/901858 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 0/903513/903513 | 0/903513/903513 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 0/893797/893797 | 0/893797/893797 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 3589566/3589566/0 | 3589566/3589566/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 3588744/3588744/0 | 3588744/3588744/0 |
| `hist.total/dropped` | 0/0 | 0/0 | 0/0 |

### Iteration 1

- Classification: `blocked_hist_ingress_or_stats`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'off', 'mts_expected_latency': None, 'ring_ctrl_written': 1}`
- Ingress select status: `0x00000403`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 3718311 | 3718311 |
| `mts1.total_hits` | 0 | 3717556 | 3717556 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 0/929068/929068 | 0/929068/929068 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 0/934845/934845 | 0/934845/934845 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 0/932604/932604 | 0/932604/932604 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 0/921794/921794 | 0/921794/921794 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 0/929120/929120 | 0/929120/929120 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 0/936861/936861 | 0/936861/936861 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 0/925510/925510 | 0/925510/925510 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 0/926065/926065 | 0/926065/926065 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 3718311/3718311/0 | 3718311/3718311/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 3717556/3717556/0 | 3717556/3717556/0 |
| `hist.total/dropped` | 0/0 | 0/0 | 0/0 |

