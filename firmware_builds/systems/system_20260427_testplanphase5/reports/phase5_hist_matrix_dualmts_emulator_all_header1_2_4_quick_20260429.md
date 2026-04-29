# Phase 5 Histogram Statistics Matrix

- Timestamp: `2026-04-29T17:03:37`
- Firmware vehicle: `top_nostp_pipe dual-MTS histogram 26.1.4 Quartus checksum 0x13DB4566 cksum 0xB4F49A95`
- SC link: `2`
- FEB target: `7`
- Sources: `emulator`
- Real-lane availability mask: `0x00000009`
- Mixed emulator-source mask: `0x000000F6`
- Duration per run: `100 ms`
- Result: `27 PASS / 0 PASS_PARTIAL / 0 FAIL / 0 BLOCKED`

## Summary

| # | Scenario | Source | Scope | Requested | Effective emu | Effective real/LVDS | Hist profile | Hits | Drops | MTS | Discard | CRC | Ring InErr | Status |
|---:|---|---|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---|
| 0 | `header_1` | `emulator` | `all` | `0x000000FF` | `0x000000FF` | `0x000001FF` | `delay-mts-both` | 1714160 | 0 | 1453512 | 0 | 0 | 0 | `PASS` |
| 1 | `header_1` | `emulator` | `lane0` | `0x00000001` | `0x00000001` | `0x000001FF` | `delay-mts-both` | 213061 | 0 | 177340 | 0 | 0 | 0 | `PASS` |
| 2 | `header_1` | `emulator` | `lane1` | `0x00000002` | `0x00000002` | `0x000001FF` | `delay-mts-both` | 204192 | 0 | 174620 | 0 | 0 | 0 | `PASS` |
| 3 | `header_1` | `emulator` | `lane2` | `0x00000004` | `0x00000004` | `0x000001FF` | `delay-mts-both` | 219118 | 0 | 178228 | 0 | 0 | 0 | `PASS` |
| 4 | `header_1` | `emulator` | `lane3` | `0x00000008` | `0x00000008` | `0x000001FF` | `delay-mts-both` | 219359 | 0 | 180996 | 0 | 0 | 0 | `PASS` |
| 5 | `header_1` | `emulator` | `lane4` | `0x00000010` | `0x00000010` | `0x000001FF` | `delay-mts-both` | 215004 | 0 | 185942 | 0 | 0 | 0 | `PASS` |
| 6 | `header_1` | `emulator` | `lane5` | `0x00000020` | `0x00000020` | `0x000001FF` | `delay-mts-both` | 214786 | 0 | 184742 | 0 | 0 | 0 | `PASS` |
| 7 | `header_1` | `emulator` | `lane6` | `0x00000040` | `0x00000040` | `0x000001FF` | `delay-mts-both` | 215880 | 0 | 184933 | 0 | 0 | 0 | `PASS` |
| 8 | `header_1` | `emulator` | `lane7` | `0x00000080` | `0x00000080` | `0x000001FF` | `delay-mts-both` | 220785 | 0 | 181109 | 0 | 0 | 0 | `PASS` |
| 9 | `header_2` | `emulator` | `all` | `0x000000FF` | `0x000000FF` | `0x000001FF` | `delay-mts-both` | 3522448 | 0 | 2856192 | 0 | 0 | 0 | `PASS` |
| 10 | `header_2` | `emulator` | `lane0` | `0x00000001` | `0x00000001` | `0x000001FF` | `delay-mts-both` | 430052 | 0 | 355074 | 0 | 0 | 0 | `PASS` |
| 11 | `header_2` | `emulator` | `lane1` | `0x00000002` | `0x00000002` | `0x000001FF` | `delay-mts-both` | 438366 | 0 | 360548 | 0 | 0 | 0 | `PASS` |
| 12 | `header_2` | `emulator` | `lane2` | `0x00000004` | `0x00000004` | `0x000001FF` | `delay-mts-both` | 413297 | 0 | 356472 | 0 | 0 | 0 | `PASS` |
| 13 | `header_2` | `emulator` | `lane3` | `0x00000008` | `0x00000008` | `0x000001FF` | `delay-mts-both` | 441582 | 0 | 353796 | 0 | 0 | 0 | `PASS` |
| 14 | `header_2` | `emulator` | `lane4` | `0x00000010` | `0x00000010` | `0x000001FF` | `delay-mts-both` | 431920 | 0 | 369162 | 0 | 0 | 0 | `PASS` |
| 15 | `header_2` | `emulator` | `lane5` | `0x00000020` | `0x00000020` | `0x000001FF` | `delay-mts-both` | 423558 | 0 | 357308 | 0 | 0 | 0 | `PASS` |
| 16 | `header_2` | `emulator` | `lane6` | `0x00000040` | `0x00000040` | `0x000001FF` | `delay-mts-both` | 429644 | 0 | 365404 | 0 | 0 | 0 | `PASS` |
| 17 | `header_2` | `emulator` | `lane7` | `0x00000080` | `0x00000080` | `0x000001FF` | `delay-mts-both` | 437736 | 0 | 365818 | 0 | 0 | 0 | `PASS` |
| 18 | `header_4` | `emulator` | `all` | `0x000000FF` | `0x000000FF` | `0x000001FF` | `delay-mts-both` | 7069568 | 0 | 5750624 | 0 | 0 | 0 | `PASS` |
| 19 | `header_4` | `emulator` | `lane0` | `0x00000001` | `0x00000001` | `0x000001FF` | `delay-mts-both` | 846300 | 0 | 709744 | 0 | 0 | 0 | `PASS` |
| 20 | `header_4` | `emulator` | `lane1` | `0x00000002` | `0x00000002` | `0x000001FF` | `delay-mts-both` | 857572 | 0 | 708968 | 0 | 0 | 0 | `PASS` |
| 21 | `header_4` | `emulator` | `lane2` | `0x00000004` | `0x00000004` | `0x000001FF` | `delay-mts-both` | 823240 | 0 | 703788 | 0 | 0 | 0 | `PASS` |
| 22 | `header_4` | `emulator` | `lane3` | `0x00000008` | `0x00000008` | `0x000001FF` | `delay-mts-both` | 825980 | 0 | 700644 | 0 | 0 | 0 | `PASS` |
| 23 | `header_4` | `emulator` | `lane4` | `0x00000010` | `0x00000010` | `0x000001FF` | `delay-mts-both` | 834736 | 0 | 726140 | 0 | 0 | 0 | `PASS` |
| 24 | `header_4` | `emulator` | `lane5` | `0x00000020` | `0x00000020` | `0x000001FF` | `delay-mts-both` | 807224 | 0 | 710980 | 0 | 0 | 0 | `PASS` |
| 25 | `header_4` | `emulator` | `lane6` | `0x00000040` | `0x00000040` | `0x000001FF` | `delay-mts-both` | 843304 | 0 | 729084 | 0 | 0 | 0 | `PASS` |
| 26 | `header_4` | `emulator` | `lane7` | `0x00000080` | `0x00000080` | `0x000001FF` | `delay-mts-both` | 829516 | 0 | 719332 | 0 | 0 | 0 | `PASS` |

## Notes

- `PASS_PARTIAL` means the requested `all` real-MuTRiG scope was reduced to the currently configured real lanes, mask `0x09` by default. It is evidence, but not full eight-MuTRiG closure.
- Delay scenarios use histogram profile `delay-mts-both`, i.e. `histogram_statistics_0.CONTROL.mode = -7`, which samples `mts_preprocessor_0.ts_delta` on debug_1 and `mts_preprocessor_1.ts_delta` on debug_2 into one delay PDF.
- Histogram bin-memory readout is not used by this runner; the current SC path returns `RSP3` on `hist_bin` read/write transactions, so screenshots are CSR/counter evidence until that aperture is debugged.
