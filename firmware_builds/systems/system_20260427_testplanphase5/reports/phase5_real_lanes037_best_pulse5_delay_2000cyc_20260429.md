# Phase 5 Histogram Statistics Matrix

- Timestamp: `2026-04-30T00:25:36`
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
- Result: `1 PASS / 0 PASS_PARTIAL / 2 FAIL / 0 BLOCKED`

## Summary

| # | Scenario | Source | Scope | Requested | Mux emu select | Effective emu | Effective real/LVDS | Hist profile | Hits | Rate Exp | Rate Err | Drops | MTS | Discard | CRC | Ring InErr | Status |
|---:|---|---|---|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | `delay_100k` | `real` | `lane0` | `0x00000001` | `0x000000FE` | `0x00000000` | `0x00000001` | `delay-mts-both` | 1141314 | 0 | 0 | 0 | 5201873 | 0 | 0 | 0 | `PASS` |
| 1 | `delay_100k` | `real` | `lane3` | `0x00000008` | `0x000000F7` | `0x00000000` | `0x00000008` | `delay-mts-both` | 585982 | 0 | 0 | 0 | 2150386 | 27 | 0 | 0 | `FAIL` |
| 2 | `delay_100k` | `real` | `lane7` | `0x00000080` | `0x0000007F` | `0x00000000` | `0x00000080` | `delay-mts-both` | 1291129 | 0 | 0 | 0 | 5365106 | 7198 | 0 | 0 | `FAIL` |

## Notes

- `PASS_PARTIAL` means the requested `all` real-MuTRiG scope was reduced to the currently configured real lanes, mask `0x09` by default. It is evidence, but not full eight-MuTRiG closure.
- Rate scenarios use the Phase-5 histogram preset: `INTERVAL_CFG = 125000000` (1 s at 125 MHz) and update key `data[38:30] = {ASIC[3:0], channel[4:0]}` for 256-channel global-rate bins. Rate-mode PASS requires the v26.1.6 `LAST_INTERVAL_TOTAL_HITS` CSR and aggregate hits within +/-1% of the pulse-interval expectation.
- Delay scenarios use histogram profile `delay-mts-both`, i.e. `histogram_statistics_0.CONTROL.mode = -7`, which samples `mts_preprocessor_0.ts_delta` on debug_1 and `mts_preprocessor_1.ts_delta` on debug_2 into one delay PDF. Current mode -7 does not carry a lane tag through the histogram CSR filter; eight-lane overlays require eight isolated lane-source runs unless the RTL is extended with lane-tagged debug filtering.
- Final closure must use raw histogram-bin readout and DISLIN plots; this matrix remains quick CSR triage and does not replace the histogram plot evidence.
