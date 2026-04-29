# Phase 5 Histogram Statistics Matrix

- Timestamp: `2026-04-29T14:31:00`
- Firmware vehicle: `top_stp_pipe_phase5_injector.sof checksum 0x13ED52E6`
- SC link: `2`
- FEB target: `7`
- Sources: `emulator`
- Real-lane availability mask: `0x00000009`
- Mixed emulator-source mask: `0x000000F6`
- Duration per run: `100 ms`
- Result: `9 PASS / 0 PASS_PARTIAL / 3 FAIL / 0 BLOCKED`

## Summary

| # | Scenario | Source | Scope | Requested | Effective emu | Effective real/LVDS | Hist profile | Hits | Drops | MTS | Discard | CRC | Ring InErr | Status |
|---:|---|---|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---|
| 0 | `header_1` | `emulator` | `lane1` | `0x00000002` | `0x00000002` | `0x000001FF` | `delay-debug1` | 236624 | 0 | 202840 | 0 | 0 | 0 | `PASS` |
| 1 | `header_1` | `emulator` | `lane2` | `0x00000004` | `0x00000004` | `0x000001FF` | `delay-debug1` | 208197 | 0 | 177718 | 0 | 0 | 0 | `PASS` |
| 2 | `header_1` | `emulator` | `lane3` | `0x00000008` | `0x00000008` | `0x000001FF` | `delay-debug1` | 206421 | 0 | 173567 | 0 | 0 | 0 | `PASS` |
| 3 | `header_1` | `emulator` | `lane4` | `0x00000010` | `0x00000010` | `0x000001FF` | `delay-debug1` | 0 | 0 | 178109 | 0 | 0 | 0 | `FAIL` |
| 4 | `header_2` | `emulator` | `lane1` | `0x00000002` | `0x00000002` | `0x000001FF` | `delay-debug1` | 411598 | 0 | 351910 | 0 | 0 | 0 | `PASS` |
| 5 | `header_2` | `emulator` | `lane2` | `0x00000004` | `0x00000004` | `0x000001FF` | `delay-debug1` | 423254 | 0 | 354034 | 0 | 0 | 0 | `PASS` |
| 6 | `header_2` | `emulator` | `lane3` | `0x00000008` | `0x00000008` | `0x000001FF` | `delay-debug1` | 397048 | 0 | 349570 | 0 | 0 | 0 | `PASS` |
| 7 | `header_2` | `emulator` | `lane4` | `0x00000010` | `0x00000010` | `0x000001FF` | `delay-debug1` | 0 | 0 | 363908 | 0 | 0 | 0 | `FAIL` |
| 8 | `header_4` | `emulator` | `lane1` | `0x00000002` | `0x00000002` | `0x000001FF` | `delay-debug1` | 824496 | 0 | 710448 | 0 | 0 | 0 | `PASS` |
| 9 | `header_4` | `emulator` | `lane2` | `0x00000004` | `0x00000004` | `0x000001FF` | `delay-debug1` | 813540 | 0 | 701576 | 0 | 0 | 0 | `PASS` |
| 10 | `header_4` | `emulator` | `lane3` | `0x00000008` | `0x00000008` | `0x000001FF` | `delay-debug1` | 810688 | 0 | 703724 | 0 | 0 | 0 | `PASS` |
| 11 | `header_4` | `emulator` | `lane4` | `0x00000010` | `0x00000010` | `0x000001FF` | `delay-debug1` | 0 | 0 | 725632 | 0 | 0 | 0 | `FAIL` |

## Notes

- `PASS_PARTIAL` means the requested `all` real-MuTRiG scope was reduced to the currently configured real lanes, mask `0x09` by default. It is evidence, but not full eight-MuTRiG closure.
- Delay scenarios use histogram profile `delay-debug1`, i.e. `histogram_statistics_0.CONTROL.mode = -1`, which selects `mts_preprocessor_0.ts_delta` on debug input 1.
- Histogram bin-memory readout is not used by this runner; the current SC path returns `RSP3` on `hist_bin` read/write transactions, so screenshots are CSR/counter evidence until that aperture is debugged.
