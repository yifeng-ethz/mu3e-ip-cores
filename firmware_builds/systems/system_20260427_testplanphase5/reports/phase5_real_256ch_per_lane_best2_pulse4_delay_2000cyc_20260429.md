# Phase 5 Histogram Statistics Matrix

- Timestamp: `2026-04-30T00:31:08`
- Firmware vehicle: `top_stp_pipe_phase5_injector.sof checksum 0x13F0D32A`
- SC link: `2`
- FEB target: `7`
- Sources: `real`
- Real-lane availability mask: `0x000000FF`
- Mixed emulator-source mask: `0x000000F6`
- Duration per run: `250 ms`
- Real hits per lane for rate expectation: `32`
- MTS expected latency override: `2000`
- MTS delay-ts field override: `t`
- MTS drop-delay-error override: `keep`
- Ring filter-inerr override: `keep`
- Result: `8 PASS / 0 PASS_PARTIAL / 0 FAIL / 0 BLOCKED`

## Summary

| # | Scenario | Source | Scope | Requested | Mux emu select | Effective emu | Effective real/LVDS | Hist profile | Hits | Rate Exp | Rate Err | Drops | MTS | Discard | CRC | Ring InErr | Status |
|---:|---|---|---|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | `delay_100k` | `real` | `lane0` | `0x00000001` | `0x000000FE` | `0x00000000` | `0x00000001` | `delay-mts-both` | 1138853 | 0 | 0 | 0 | 4938972 | 0 | 0 | 0 | `PASS` |
| 1 | `delay_100k` | `real` | `lane1` | `0x00000002` | `0x000000FD` | `0x00000000` | `0x00000002` | `delay-mts-both` | 1445607 | 0 | 0 | 0 | 6221826 | 0 | 0 | 0 | `PASS` |
| 2 | `delay_100k` | `real` | `lane2` | `0x00000004` | `0x000000FB` | `0x00000000` | `0x00000004` | `delay-mts-both` | 1611497 | 0 | 0 | 0 | 6652644 | 0 | 0 | 0 | `PASS` |
| 3 | `delay_100k` | `real` | `lane3` | `0x00000008` | `0x000000F7` | `0x00000000` | `0x00000008` | `delay-mts-both` | 495871 | 0 | 0 | 0 | 2157879 | 0 | 0 | 0 | `PASS` |
| 4 | `delay_100k` | `real` | `lane4` | `0x00000010` | `0x000000EF` | `0x00000000` | `0x00000010` | `delay-mts-both` | 876086 | 0 | 0 | 0 | 3813792 | 0 | 0 | 0 | `PASS` |
| 5 | `delay_100k` | `real` | `lane5` | `0x00000020` | `0x000000DF` | `0x00000000` | `0x00000020` | `delay-mts-both` | 1447816 | 0 | 0 | 0 | 5629159 | 0 | 0 | 0 | `PASS` |
| 6 | `delay_100k` | `real` | `lane6` | `0x00000040` | `0x000000BF` | `0x00000000` | `0x00000040` | `delay-mts-both` | 735386 | 0 | 0 | 0 | 3688878 | 0 | 0 | 0 | `PASS` |
| 7 | `delay_100k` | `real` | `lane7` | `0x00000080` | `0x0000007F` | `0x00000000` | `0x00000080` | `delay-mts-both` | 1268454 | 0 | 0 | 0 | 5308393 | 0 | 0 | 0 | `PASS` |

## Notes

- `PASS_PARTIAL` means the requested `all` real-MuTRiG scope was reduced to the currently configured real lanes, mask `0x09` by default. It is evidence, but not full eight-MuTRiG closure.
- Rate scenarios use the Phase-5 histogram preset: `INTERVAL_CFG = 125000000` (1 s at 125 MHz) and update key `data[38:30] = {ASIC[3:0], channel[4:0]}` for 256-channel global-rate bins. Rate-mode PASS requires the v26.1.6 `LAST_INTERVAL_TOTAL_HITS` CSR and aggregate hits within +/-1% of the pulse-interval expectation.
- Delay scenarios use histogram profile `delay-mts-both`, i.e. `histogram_statistics_0.CONTROL.mode = -7`, which samples `mts_preprocessor_0.ts_delta` on debug_1 and `mts_preprocessor_1.ts_delta` on debug_2 into one delay PDF. Current mode -7 does not carry a lane tag through the histogram CSR filter; eight-lane overlays require eight isolated lane-source runs unless the RTL is extended with lane-tagged debug filtering.
- Final closure must use raw histogram-bin readout and DISLIN plots; this matrix remains quick CSR triage and does not replace the histogram plot evidence.
