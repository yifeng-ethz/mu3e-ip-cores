# Phase 4 Stage Counter Probe

- Timestamp: `2026-04-25T16:44:40`
- SC link: `2`
- FEB target: `7`
- Hit rate: `0x0800`
- Duration: `50 ms`
- Iterations: `2`
- Ring input-error filter override: `keep`
- MTS expected latency override: `2000`

## Summary

| Iter | Class | Emu Frames | MTS Hits | Ring InErr | Ring Push | Ring Pop | Frame Actual | Hist Total | Hist Drop | CRC Err | Ingress | SC Flags | SC Drops |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | `mixed_or_saturated` | 82144 | 5165926 | 0 | 5165926 | 5165926 | 5165926 | 2583270 | 31357 | 0 | `0x00000603` | `0x00000000` | 0 |
| 1 | `mixed_or_saturated` | 83512 | 5251935 | 0 | 5251935 | 5251935 | 5251935 | 2626248 | 84711 | 0 | `0x00000403` | `0x00000000` | 0 |

## Per-Iteration Stage Detail

### Iteration 0

- Classification: `mixed_or_saturated`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': 2000}`
- Ingress select status: `0x00000403`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 2583270 | 2583270 |
| `mts1.total_hits` | 0 | 2582656 | 2582656 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 0/641886/641886 | 0/641886/641886 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 0/650367/650367 | 0/650367/650367 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 0/648615/648615 | 0/648615/648615 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 0/642402/642402 | 0/642402/642402 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 0/647010/647010 | 0/647010/647010 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 0/647337/647337 | 0/647337/647337 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 0/645195/645195 | 0/645195/645195 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 0/643114/643114 | 0/643114/643114 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 2583270/2583270/0 | 2583270/2583270/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 2582656/2582656/0 | 2582656/2582656/0 |
| `hist.total/dropped` | 0/0 | 2583270/31357 | 2583270/31357 |

### Iteration 1

- Classification: `mixed_or_saturated`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': 2000}`
- Ingress select status: `0x00000403`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 2626248 | 2626248 |
| `mts1.total_hits` | 0 | 2625687 | 2625687 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 0/656445/656445 | 0/656445/656445 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 0/663552/663552 | 0/663552/663552 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 0/656728/656728 | 0/656728/656728 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 0/649523/649523 | 0/649523/649523 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 0/658105/658105 | 0/658105/658105 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 0/660731/660731 | 0/660731/660731 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 0/655143/655143 | 0/655143/655143 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 0/651708/651708 | 0/651708/651708 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 2626248/2626248/0 | 2626248/2626248/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 2625687/2625687/0 | 2625687/2625687/0 |
| `hist.total/dropped` | 0/0 | 2626248/84711 | 2626248/84711 |

