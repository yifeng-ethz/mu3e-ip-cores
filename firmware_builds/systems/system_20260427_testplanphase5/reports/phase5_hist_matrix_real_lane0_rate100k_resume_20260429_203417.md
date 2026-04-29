# Phase 5 Histogram Statistics Matrix

- Timestamp: `2026-04-29T20:34:17`
- Firmware vehicle: `top_nostp_pipe dual-MTS checksum 0x13DB4566, resume real lane0 ch16 cfg`
- SC link: `2`
- FEB target: `7`
- Sources: `real`
- Real-lane availability mask: `0x000000FF`
- Mixed emulator-source mask: `0x000000F6`
- Duration per run: `1100 ms`
- Result: `0 PASS / 0 PASS_PARTIAL / 1 FAIL / 0 BLOCKED`

## Summary

| # | Scenario | Source | Scope | Requested | Effective emu | Effective real/LVDS | Hist profile | Hits | Drops | MTS | Discard | CRC | Ring InErr | Status |
|---:|---|---|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---|
| 0 | `rate_100k` | `real` | `lane0` | `0x00000001` | `0x00000000` | `0x00000001` | `rate` | 0 | 0 | 0 | 0 | 0 | 0 | `FAIL` |

## Notes

- `PASS_PARTIAL` means the requested `all` real-MuTRiG scope was reduced to the currently configured real lanes, mask `0x09` by default. It is evidence, but not full eight-MuTRiG closure.
- Rate scenarios use the Phase-5 histogram preset: `INTERVAL_CFG = 125000000` (1 s at 125 MHz) and update key `data[38:30] = {ASIC[3:0], channel[4:0]}` for 256-channel global-rate bins.
- Delay scenarios use histogram profile `delay-mts-both`, i.e. `histogram_statistics_0.CONTROL.mode = -7`, which samples `mts_preprocessor_0.ts_delta` on debug_1 and `mts_preprocessor_1.ts_delta` on debug_2 into one delay PDF. Current mode -7 does not carry a lane tag through the histogram CSR filter; eight-lane overlays require eight isolated lane-source runs unless the RTL is extended with lane-tagged debug filtering.
- Final closure must use raw histogram-bin readout and DISLIN plots; this matrix remains quick CSR triage and does not replace the histogram plot evidence.
