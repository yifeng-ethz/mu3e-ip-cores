# Phase 5 Histogram Statistics Matrix

- Timestamp: `2026-04-30T00:03:46`
- Firmware vehicle: `top_stp_pipe_phase5_injector.sof checksum 0x13F0D32A`
- SC link: `2`
- FEB target: `7`
- Sources: `real`
- Real-lane availability mask: `0x000000FF`
- Mixed emulator-source mask: `0x000000F6`
- Duration per run: `1200 ms`
- Real hits per lane for rate expectation: `32`
- MTS expected latency override: `keep`
- MTS delay-ts field override: `keep`
- MTS drop-delay-error override: `keep`
- Ring filter-inerr override: `keep`
- Result: `0 PASS / 0 PASS_PARTIAL / 8 FAIL / 0 BLOCKED`

## Summary

| # | Scenario | Source | Scope | Requested | Mux emu select | Effective emu | Effective real/LVDS | Hist profile | Hits | Rate Exp | Rate Err | Drops | MTS | Discard | CRC | Ring InErr | Status |
|---:|---|---|---|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | `rate_100k` | `real` | `lane0` | `0x00000001` | `0x000000FE` | `0x00000000` | `0x00000001` | `rate` | 2263381 | 3200000 | -936619 | 0 | 7441126 | 0 | 0 | 0 | `FAIL` |
| 1 | `rate_100k` | `real` | `lane1` | `0x00000002` | `0x000000FD` | `0x00000000` | `0x00000002` | `rate` | 2695707 | 3200000 | -504293 | 0 | 8843661 | 0 | 0 | 0 | `FAIL` |
| 2 | `rate_100k` | `real` | `lane2` | `0x00000004` | `0x000000FB` | `0x00000000` | `0x00000004` | `rate` | 2861788 | 3200000 | -338212 | 0 | 9568962 | 1114 | 0 | 0 | `FAIL` |
| 3 | `rate_100k` | `real` | `lane3` | `0x00000008` | `0x000000F7` | `0x00000000` | `0x00000008` | `rate` | 1456948 | 3200000 | -1743052 | 0 | 4825035 | 10 | 0 | 0 | `FAIL` |
| 4 | `rate_100k` | `real` | `lane4` | `0x00000010` | `0x000000EF` | `0x00000000` | `0x00000010` | `rate` | 1827828 | 3200000 | -1372172 | 0 | 6070216 | 0 | 0 | 0 | `FAIL` |
| 5 | `rate_100k` | `real` | `lane5` | `0x00000020` | `0x000000DF` | `0x00000000` | `0x00000020` | `rate` | 2373149 | 3200000 | -826851 | 0 | 7954520 | 0 | 0 | 0 | `FAIL` |
| 6 | `rate_100k` | `real` | `lane6` | `0x00000040` | `0x000000BF` | `0x00000000` | `0x00000040` | `rate` | 1530909 | 3200000 | -1669091 | 0 | 5083400 | 0 | 0 | 0 | `FAIL` |
| 7 | `rate_100k` | `real` | `lane7` | `0x00000080` | `0x0000007F` | `0x00000000` | `0x00000080` | `rate` | 2261293 | 3200000 | -938707 | 0 | 7900307 | 376881 | 0 | 0 | `FAIL` |

## Notes

- `PASS_PARTIAL` means the requested `all` real-MuTRiG scope was reduced to the currently configured real lanes, mask `0x09` by default. It is evidence, but not full eight-MuTRiG closure.
- Rate scenarios use the Phase-5 histogram preset: `INTERVAL_CFG = 125000000` (1 s at 125 MHz) and update key `data[38:30] = {ASIC[3:0], channel[4:0]}` for 256-channel global-rate bins. Rate-mode PASS requires the v26.1.6 `LAST_INTERVAL_TOTAL_HITS` CSR and aggregate hits within +/-1% of the pulse-interval expectation.
- Delay scenarios use histogram profile `delay-mts-both`, i.e. `histogram_statistics_0.CONTROL.mode = -7`, which samples `mts_preprocessor_0.ts_delta` on debug_1 and `mts_preprocessor_1.ts_delta` on debug_2 into one delay PDF. Current mode -7 does not carry a lane tag through the histogram CSR filter; eight-lane overlays require eight isolated lane-source runs unless the RTL is extended with lane-tagged debug filtering.
- Final closure must use raw histogram-bin readout and DISLIN plots; this matrix remains quick CSR triage and does not replace the histogram plot evidence.
