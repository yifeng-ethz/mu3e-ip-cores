# Phase 5 Histogram Statistics Matrix

- Timestamp: `2026-04-29T16:55:14`
- Firmware vehicle: `top_nostp_pipe dual-MTS histogram 26.1.4 Quartus checksum 0x13DB4566 cksum 0xB4F49A95`
- SC link: `2`
- FEB target: `7`
- Sources: `emulator`
- Real-lane availability mask: `0x00000009`
- Mixed emulator-source mask: `0x000000F6`
- Duration per run: `100 ms`
- Result: `9 PASS / 0 PASS_PARTIAL / 0 FAIL / 0 BLOCKED`

## Summary

| # | Scenario | Source | Scope | Requested | Effective emu | Effective real/LVDS | Hist profile | Hits | Drops | MTS | Discard | CRC | Ring InErr | Status |
|---:|---|---|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---|
| 0 | `delay_100k` | `emulator` | `all` | `0x000000FF` | `0x000000FF` | `0x000001FF` | `delay-mts-both` | 2213464 | 0 | 1832216 | 0 | 0 | 0 | `PASS` |
| 1 | `delay_100k` | `emulator` | `lane0` | `0x00000001` | `0x00000001` | `0x000001FF` | `delay-mts-both` | 293736 | 0 | 221313 | 0 | 0 | 0 | `PASS` |
| 2 | `delay_100k` | `emulator` | `lane1` | `0x00000002` | `0x00000002` | `0x000001FF` | `delay-mts-both` | 285351 | 0 | 225324 | 0 | 0 | 0 | `PASS` |
| 3 | `delay_100k` | `emulator` | `lane2` | `0x00000004` | `0x00000004` | `0x000001FF` | `delay-mts-both` | 278873 | 0 | 218782 | 0 | 0 | 0 | `PASS` |
| 4 | `delay_100k` | `emulator` | `lane3` | `0x00000008` | `0x00000008` | `0x000001FF` | `delay-mts-both` | 260405 | 0 | 220626 | 0 | 0 | 0 | `PASS` |
| 5 | `delay_100k` | `emulator` | `lane4` | `0x00000010` | `0x00000010` | `0x000001FF` | `delay-mts-both` | 253919 | 0 | 221974 | 0 | 0 | 0 | `PASS` |
| 6 | `delay_100k` | `emulator` | `lane5` | `0x00000020` | `0x00000020` | `0x000001FF` | `delay-mts-both` | 257019 | 0 | 222445 | 0 | 0 | 0 | `PASS` |
| 7 | `delay_100k` | `emulator` | `lane6` | `0x00000040` | `0x00000040` | `0x000001FF` | `delay-mts-both` | 267010 | 0 | 226016 | 0 | 0 | 0 | `PASS` |
| 8 | `delay_100k` | `emulator` | `lane7` | `0x00000080` | `0x00000080` | `0x000001FF` | `delay-mts-both` | 260392 | 0 | 222950 | 0 | 0 | 0 | `PASS` |

## Notes

- `PASS_PARTIAL` means the requested `all` real-MuTRiG scope was reduced to the currently configured real lanes, mask `0x09` by default. It is evidence, but not full eight-MuTRiG closure.
- Delay scenarios use histogram profile `delay-mts-both`, i.e. `histogram_statistics_0.CONTROL.mode = -7`, which samples `mts_preprocessor_0.ts_delta` on debug_1 and `mts_preprocessor_1.ts_delta` on debug_2 into one delay PDF.
- Histogram bin-memory readout is not used by this runner; the current SC path returns `RSP3` on `hist_bin` read/write transactions, so screenshots are CSR/counter evidence until that aperture is debugged.
