# Phase 5 Histogram Statistics Matrix

- Timestamp: `2026-04-29T16:58:16`
- Firmware vehicle: `top_nostp_pipe dual-MTS histogram 26.1.4 Quartus checksum 0x13DB4566 cksum 0xB4F49A95`
- SC link: `2`
- FEB target: `7`
- Sources: `emulator`
- Real-lane availability mask: `0x00000009`
- Mixed emulator-source mask: `0x000000F6`
- Duration per run: `100 ms`
- Result: `18 PASS / 0 PASS_PARTIAL / 0 FAIL / 0 BLOCKED`

## Summary

| # | Scenario | Source | Scope | Requested | Effective emu | Effective real/LVDS | Hist profile | Hits | Drops | MTS | Discard | CRC | Ring InErr | Status |
|---:|---|---|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---|
| 0 | `rate_100k` | `emulator` | `all` | `0x000000FF` | `0x000000FF` | `0x000001FF` | `rate` | 2148816 | 0 | 1796444 | 0 | 0 | 0 | `PASS` |
| 1 | `rate_100k` | `emulator` | `lane0` | `0x00000001` | `0x00000001` | `0x000001FF` | `rate` | 255955 | 0 | 218825 | 0 | 0 | 0 | `PASS` |
| 2 | `rate_100k` | `emulator` | `lane1` | `0x00000002` | `0x00000002` | `0x000001FF` | `rate` | 251760 | 0 | 217065 | 0 | 0 | 0 | `PASS` |
| 3 | `rate_100k` | `emulator` | `lane2` | `0x00000004` | `0x00000004` | `0x000001FF` | `rate` | 253245 | 0 | 217721 | 0 | 0 | 0 | `PASS` |
| 4 | `rate_100k` | `emulator` | `lane3` | `0x00000008` | `0x00000008` | `0x000001FF` | `rate` | 257047 | 0 | 216650 | 0 | 0 | 0 | `PASS` |
| 5 | `rate_100k` | `emulator` | `lane4` | `0x00000010` | `0x00000010` | `0x000001FF` | `rate` | 252719 | 0 | 222869 | 0 | 0 | 0 | `PASS` |
| 6 | `rate_100k` | `emulator` | `lane5` | `0x00000020` | `0x00000020` | `0x000001FF` | `rate` | 246151 | 0 | 223430 | 0 | 0 | 0 | `PASS` |
| 7 | `rate_100k` | `emulator` | `lane6` | `0x00000040` | `0x00000040` | `0x000001FF` | `rate` | 260989 | 0 | 228134 | 0 | 0 | 0 | `PASS` |
| 8 | `rate_100k` | `emulator` | `lane7` | `0x00000080` | `0x00000080` | `0x000001FF` | `rate` | 267791 | 0 | 230428 | 0 | 0 | 0 | `PASS` |
| 9 | `rate_10k` | `emulator` | `all` | `0x000000FF` | `0x000000FF` | `0x000001FF` | `rate` | 210232 | 0 | 175996 | 0 | 0 | 0 | `PASS` |
| 10 | `rate_10k` | `emulator` | `lane0` | `0x00000001` | `0x00000001` | `0x000001FF` | `rate` | 26348 | 0 | 22164 | 0 | 0 | 0 | `PASS` |
| 11 | `rate_10k` | `emulator` | `lane1` | `0x00000002` | `0x00000002` | `0x000001FF` | `rate` | 25813 | 0 | 22031 | 0 | 0 | 0 | `PASS` |
| 12 | `rate_10k` | `emulator` | `lane2` | `0x00000004` | `0x00000004` | `0x000001FF` | `rate` | 26096 | 0 | 21909 | 0 | 0 | 0 | `PASS` |
| 13 | `rate_10k` | `emulator` | `lane3` | `0x00000008` | `0x00000008` | `0x000001FF` | `rate` | 24694 | 0 | 21872 | 0 | 0 | 0 | `PASS` |
| 14 | `rate_10k` | `emulator` | `lane4` | `0x00000010` | `0x00000010` | `0x000001FF` | `rate` | 24931 | 0 | 22465 | 0 | 0 | 0 | `PASS` |
| 15 | `rate_10k` | `emulator` | `lane5` | `0x00000020` | `0x00000020` | `0x000001FF` | `rate` | 25574 | 0 | 22202 | 0 | 0 | 0 | `PASS` |
| 16 | `rate_10k` | `emulator` | `lane6` | `0x00000040` | `0x00000040` | `0x000001FF` | `rate` | 25101 | 0 | 22153 | 0 | 0 | 0 | `PASS` |
| 17 | `rate_10k` | `emulator` | `lane7` | `0x00000080` | `0x00000080` | `0x000001FF` | `rate` | 25738 | 0 | 22399 | 0 | 0 | 0 | `PASS` |

## Notes

- `PASS_PARTIAL` means the requested `all` real-MuTRiG scope was reduced to the currently configured real lanes, mask `0x09` by default. It is evidence, but not full eight-MuTRiG closure.
- Delay scenarios use histogram profile `delay-mts-both`, i.e. `histogram_statistics_0.CONTROL.mode = -7`, which samples `mts_preprocessor_0.ts_delta` on debug_1 and `mts_preprocessor_1.ts_delta` on debug_2 into one delay PDF.
- Histogram bin-memory readout is not used by this runner; the current SC path returns `RSP3` on `hist_bin` read/write transactions, so screenshots are CSR/counter evidence until that aperture is debugged.
