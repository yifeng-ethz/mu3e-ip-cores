# Phase 5 Real MuTRiG Per-ASIC Legacy Pulse Check

- Timestamp: `2026-04-29T22:46:54`
- Stimulus: `MUTRIG_CNT_CTRL_REGISTER_W[0]` legacy `pll_test_mode(0)` real TDC-test pulse
- Period: `1250` cycles = 100 kHz at 125 MHz
- ASIC config: SMB3 XML for ASICs 0..3, SMB5 XML for ASICs 4..7; all 32 channels enabled and `tdctest_n=0`
- Each row parks non-requested real lanes on disabled emulator sources using `selected_source_mask = (~lane_mask) & 0xff`.

| ASIC | SMB | Local XML | Lane mask | Mux emu select | Class | Hist | Drops | MTS | MTS discard | Ring InErr | CRC | Frame actual | Post-end |
|---:|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | `SMB3` | 0 | `0x00000001` | `0x000000FE` | `real_source_not_reaching_histogram` | 0 | 0 | 0 | 0 | 0 | 0 | 0 | `clean` |
| 1 | `SMB3` | 1 | `0x00000002` | `0x000000FD` | `real_source_not_reaching_histogram` | 0 | 0 | 0 | 0 | 0 | 0 | 0 | `clean` |
| 2 | `SMB3` | 2 | `0x00000004` | `0x000000FB` | `real_source_not_reaching_histogram` | 0 | 0 | 0 | 0 | 0 | 0 | 0 | `clean` |
| 3 | `SMB3` | 3 | `0x00000008` | `0x000000F7` | `real_source_not_reaching_histogram` | 0 | 0 | 0 | 0 | 0 | 0 | 0 | `clean` |
| 4 | `SMB5` | 0 | `0x00000010` | `0x000000EF` | `real_source_not_reaching_histogram` | 0 | 0 | 0 | 0 | 0 | 0 | 0 | `clean` |
| 5 | `SMB5` | 1 | `0x00000020` | `0x000000DF` | `real_source_not_reaching_histogram` | 0 | 0 | 0 | 0 | 0 | 0 | 0 | `clean` |
| 6 | `SMB5` | 2 | `0x00000040` | `0x000000BF` | `real_source_not_reaching_histogram` | 0 | 0 | 0 | 0 | 0 | 0 | 0 | `clean` |
| 7 | `SMB5` | 3 | `0x00000080` | `0x0000007F` | `real_source_not_reaching_histogram` | 0 | 0 | 0 | 0 | 0 | 0 | 0 | `clean` |
