# Phase 5 Histogram Statistics Matrix

- Timestamp: `2026-04-29T16:53:58`
- Firmware vehicle: `top_nostp_pipe dual-MTS histogram 26.1.4 Quartus checksum 0x13DB4566 cksum 0xB4F49A95`
- SC link: `2`
- FEB target: `7`
- Sources: `emulator`
- Real-lane availability mask: `0x00000009`
- Mixed emulator-source mask: `0x000000F6`
- Duration per run: `100 ms`
- Result: `1 PASS / 0 PASS_PARTIAL / 0 FAIL / 0 BLOCKED`

## Summary

| # | Scenario | Source | Scope | Requested | Effective emu | Effective real/LVDS | Hist profile | Hits | Drops | MTS | Discard | CRC | Ring InErr | Status |
|---:|---|---|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---|
| 0 | `delay_100k` | `emulator` | `lane0` | `0x00000001` | `0x00000001` | `0x000001FF` | `delay-mts-both` | 252234 | 0 | 218877 | 0 | 0 | 0 | `PASS` |

## Notes

- `PASS_PARTIAL` means the requested `all` real-MuTRiG scope was reduced to the currently configured real lanes, mask `0x09` by default. It is evidence, but not full eight-MuTRiG closure.
- Delay scenarios use histogram profile `delay-mts-both`, i.e. `histogram_statistics_0.CONTROL.mode = -7`, which samples `mts_preprocessor_0.ts_delta` on debug_1 and `mts_preprocessor_1.ts_delta` on debug_2 into one delay PDF.
- Histogram bin-memory readout is not used by this runner; the current SC path returns `RSP3` on `hist_bin` read/write transactions, so screenshots are CSR/counter evidence until that aperture is debugged.
