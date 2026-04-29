# Phase 5 Histogram Statistics Matrix

- Timestamp: `2026-04-29T13:46:07`
- Firmware vehicle: `top_stp_pipe_phase5_injector.sof checksum 0x13ED52E6`
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
| 0 | `rate_10k` | `emulator` | `lane0` | `0x00000001` | `0x00000001` | `0x000001FF` | `rate` | 25619 | 0 | 21965 | 0 | 0 | 0 | `PASS` |

## Notes

- `PASS_PARTIAL` means the requested `all` real-MuTRiG scope was reduced to the currently configured real lanes, mask `0x09` by default. It is evidence, but not full eight-MuTRiG closure.
- Delay scenarios use histogram profile `delay-debug1`, i.e. `histogram_statistics_0.CONTROL.mode = -1`, which selects `mts_preprocessor_0.ts_delta` on debug input 1.
- Histogram bin-memory readout is not used by this runner; the current SC path returns `RSP3` on `hist_bin` read/write transactions, so screenshots are CSR/counter evidence until that aperture is debugged.
