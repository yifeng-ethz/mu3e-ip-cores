# Phase 5 Histogram Statistics Matrix

- Timestamp: `2026-04-29T13:47:44`
- Firmware vehicle: `top_stp_pipe_phase5_injector.sof checksum 0x13ED52E6`
- SC link: `2`
- FEB target: `7`
- Sources: `emulator,real,mixed`
- Real-lane availability mask: `0x00000009`
- Mixed emulator-source mask: `0x000000F6`
- Duration per run: `100 ms`
- Result: `87 PASS / 6 PASS_PARTIAL / 33 FAIL / 36 BLOCKED`

## Summary

| # | Scenario | Source | Scope | Requested | Effective emu | Effective real/LVDS | Hist profile | Hits | Drops | MTS | Discard | CRC | Ring InErr | Status |
|---:|---|---|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---|
| 0 | `rate_100k` | `emulator` | `all` | `0x000000FF` | `0x000000FF` | `0x000001FF` | `rate` | 983552 | 0 | 1759560 | 0 | 0 | 0 | `PASS` |
| 1 | `rate_100k` | `emulator` | `lane0` | `0x00000001` | `0x00000001` | `0x000001FF` | `rate` | 257109 | 0 | 218977 | 0 | 0 | 0 | `PASS` |
| 2 | `rate_100k` | `emulator` | `lane1` | `0x00000002` | `0x00000002` | `0x000001FF` | `rate` | 264077 | 0 | 218251 | 0 | 0 | 0 | `PASS` |
| 3 | `rate_100k` | `emulator` | `lane2` | `0x00000004` | `0x00000004` | `0x000001FF` | `rate` | 254780 | 0 | 217230 | 0 | 0 | 0 | `PASS` |
| 4 | `rate_100k` | `emulator` | `lane3` | `0x00000008` | `0x00000008` | `0x000001FF` | `rate` | 257633 | 0 | 221591 | 0 | 0 | 0 | `PASS` |
| 5 | `rate_100k` | `emulator` | `lane4` | `0x00000010` | `0x00000010` | `0x000001FF` | `rate` | 0 | 0 | 223036 | 0 | 0 | 0 | `FAIL` |
| 6 | `rate_100k` | `emulator` | `lane5` | `0x00000020` | `0x00000020` | `0x000001FF` | `rate` | 0 | 0 | 219370 | 0 | 0 | 0 | `FAIL` |
| 7 | `rate_100k` | `emulator` | `lane6` | `0x00000040` | `0x00000040` | `0x000001FF` | `rate` | 0 | 0 | 222422 | 0 | 0 | 0 | `FAIL` |
| 8 | `rate_100k` | `emulator` | `lane7` | `0x00000080` | `0x00000080` | `0x000001FF` | `rate` | 0 | 0 | 217441 | 0 | 0 | 0 | `FAIL` |
| 9 | `rate_100k` | `real` | `all` | `0x000000FF` | `0x00000000` | `0x00000009` | `rate` | 261824 | 0 | 218816 | 0 | 0 | 0 | `PASS_PARTIAL` |
| 10 | `rate_100k` | `real` | `lane0` | `0x00000001` | `0x00000000` | `0x00000001` | `rate` | 245776 | 0 | 218383 | 0 | 0 | 0 | `PASS` |
| 11 | `rate_100k` | `real` | `lane1` | `0x00000002` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 12 | `rate_100k` | `real` | `lane2` | `0x00000004` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 13 | `rate_100k` | `real` | `lane3` | `0x00000008` | `0x00000000` | `0x00000008` | `rate` | 264294 | 0 | 217347 | 0 | 0 | 0 | `PASS` |
| 14 | `rate_100k` | `real` | `lane4` | `0x00000010` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 15 | `rate_100k` | `real` | `lane5` | `0x00000020` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 16 | `rate_100k` | `real` | `lane6` | `0x00000040` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 17 | `rate_100k` | `real` | `lane7` | `0x00000080` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 18 | `rate_100k` | `mixed` | `all` | `0x000000FF` | `0x000000F6` | `0x00000009` | `rate` | 780042 | 0 | 1531522 | 0 | 0 | 0 | `PASS` |
| 19 | `rate_100k` | `mixed` | `lane0` | `0x00000001` | `0x00000000` | `0x00000001` | `rate` | 265425 | 0 | 221251 | 0 | 0 | 0 | `PASS` |
| 20 | `rate_100k` | `mixed` | `lane1` | `0x00000002` | `0x00000002` | `0x00000000` | `rate` | 507924 | 0 | 439885 | 0 | 0 | 0 | `PASS` |
| 21 | `rate_100k` | `mixed` | `lane2` | `0x00000004` | `0x00000004` | `0x00000000` | `rate` | 537250 | 0 | 439239 | 0 | 0 | 0 | `PASS` |
| 22 | `rate_100k` | `mixed` | `lane3` | `0x00000008` | `0x00000000` | `0x00000008` | `rate` | 268599 | 0 | 223166 | 0 | 0 | 0 | `PASS` |
| 23 | `rate_100k` | `mixed` | `lane4` | `0x00000010` | `0x00000010` | `0x00000000` | `rate` | 266845 | 0 | 447224 | 0 | 0 | 0 | `PASS` |
| 24 | `rate_100k` | `mixed` | `lane5` | `0x00000020` | `0x00000020` | `0x00000000` | `rate` | 286138 | 0 | 460463 | 0 | 0 | 0 | `PASS` |
| 25 | `rate_100k` | `mixed` | `lane6` | `0x00000040` | `0x00000040` | `0x00000000` | `rate` | 268952 | 0 | 442898 | 0 | 0 | 0 | `PASS` |
| 26 | `rate_100k` | `mixed` | `lane7` | `0x00000080` | `0x00000080` | `0x00000000` | `rate` | 254030 | 0 | 439555 | 0 | 0 | 0 | `PASS` |
| 27 | `rate_10k` | `emulator` | `all` | `0x000000FF` | `0x000000FF` | `0x000001FF` | `rate` | 106440 | 0 | 177248 | 0 | 0 | 0 | `PASS` |
| 28 | `rate_10k` | `emulator` | `lane0` | `0x00000001` | `0x00000001` | `0x000001FF` | `rate` | 27262 | 0 | 22134 | 0 | 0 | 0 | `PASS` |
| 29 | `rate_10k` | `emulator` | `lane1` | `0x00000002` | `0x00000002` | `0x000001FF` | `rate` | 25258 | 0 | 21920 | 0 | 0 | 0 | `PASS` |
| 30 | `rate_10k` | `emulator` | `lane2` | `0x00000004` | `0x00000004` | `0x000001FF` | `rate` | 26085 | 0 | 22029 | 0 | 0 | 0 | `PASS` |
| 31 | `rate_10k` | `emulator` | `lane3` | `0x00000008` | `0x00000008` | `0x000001FF` | `rate` | 24593 | 0 | 21658 | 0 | 0 | 0 | `PASS` |
| 32 | `rate_10k` | `emulator` | `lane4` | `0x00000010` | `0x00000010` | `0x000001FF` | `rate` | 0 | 0 | 22275 | 0 | 0 | 0 | `FAIL` |
| 33 | `rate_10k` | `emulator` | `lane5` | `0x00000020` | `0x00000020` | `0x000001FF` | `rate` | 0 | 0 | 22127 | 0 | 0 | 0 | `FAIL` |
| 34 | `rate_10k` | `emulator` | `lane6` | `0x00000040` | `0x00000040` | `0x000001FF` | `rate` | 0 | 0 | 22233 | 0 | 0 | 0 | `FAIL` |
| 35 | `rate_10k` | `emulator` | `lane7` | `0x00000080` | `0x00000080` | `0x000001FF` | `rate` | 0 | 0 | 22741 | 0 | 0 | 0 | `FAIL` |
| 36 | `rate_10k` | `real` | `all` | `0x000000FF` | `0x00000000` | `0x00000009` | `rate` | 24970 | 0 | 21608 | 0 | 0 | 0 | `PASS_PARTIAL` |
| 37 | `rate_10k` | `real` | `lane0` | `0x00000001` | `0x00000000` | `0x00000001` | `rate` | 25062 | 0 | 21904 | 0 | 0 | 0 | `PASS` |
| 38 | `rate_10k` | `real` | `lane1` | `0x00000002` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 39 | `rate_10k` | `real` | `lane2` | `0x00000004` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 40 | `rate_10k` | `real` | `lane3` | `0x00000008` | `0x00000000` | `0x00000008` | `rate` | 25905 | 0 | 22823 | 0 | 0 | 0 | `PASS` |
| 41 | `rate_10k` | `real` | `lane4` | `0x00000010` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 42 | `rate_10k` | `real` | `lane5` | `0x00000020` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 43 | `rate_10k` | `real` | `lane6` | `0x00000040` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 44 | `rate_10k` | `real` | `lane7` | `0x00000080` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 45 | `rate_10k` | `mixed` | `all` | `0x000000FF` | `0x000000F6` | `0x00000009` | `rate` | 99102 | 0 | 176739 | 0 | 0 | 0 | `PASS` |
| 46 | `rate_10k` | `mixed` | `lane0` | `0x00000001` | `0x00000000` | `0x00000001` | `rate` | 24716 | 0 | 21334 | 0 | 0 | 0 | `PASS` |
| 47 | `rate_10k` | `mixed` | `lane1` | `0x00000002` | `0x00000002` | `0x00000000` | `rate` | 51066 | 0 | 43648 | 0 | 0 | 0 | `PASS` |
| 48 | `rate_10k` | `mixed` | `lane2` | `0x00000004` | `0x00000004` | `0x00000000` | `rate` | 50020 | 0 | 43120 | 0 | 0 | 0 | `PASS` |
| 49 | `rate_10k` | `mixed` | `lane3` | `0x00000008` | `0x00000000` | `0x00000008` | `rate` | 25085 | 0 | 21762 | 0 | 0 | 0 | `PASS` |
| 50 | `rate_10k` | `mixed` | `lane4` | `0x00000010` | `0x00000010` | `0x00000000` | `rate` | 24399 | 0 | 43769 | 0 | 0 | 0 | `PASS` |
| 51 | `rate_10k` | `mixed` | `lane5` | `0x00000020` | `0x00000020` | `0x00000000` | `rate` | 24771 | 0 | 44035 | 0 | 0 | 0 | `PASS` |
| 52 | `rate_10k` | `mixed` | `lane6` | `0x00000040` | `0x00000040` | `0x00000000` | `rate` | 25673 | 0 | 43880 | 0 | 0 | 0 | `PASS` |
| 53 | `rate_10k` | `mixed` | `lane7` | `0x00000080` | `0x00000080` | `0x00000000` | `rate` | 24803 | 0 | 44027 | 0 | 0 | 0 | `PASS` |
| 54 | `delay_100k` | `emulator` | `all` | `0x000000FF` | `0x000000FF` | `0x000001FF` | `delay-debug1` | 1032692 | 0 | 1782292 | 0 | 0 | 0 | `PASS` |
| 55 | `delay_100k` | `emulator` | `lane0` | `0x00000001` | `0x00000001` | `0x000001FF` | `delay-debug1` | 242198 | 0 | 215380 | 0 | 0 | 0 | `PASS` |
| 56 | `delay_100k` | `emulator` | `lane1` | `0x00000002` | `0x00000002` | `0x000001FF` | `delay-debug1` | 255031 | 0 | 217477 | 0 | 0 | 0 | `PASS` |
| 57 | `delay_100k` | `emulator` | `lane2` | `0x00000004` | `0x00000004` | `0x000001FF` | `delay-debug1` | 270990 | 0 | 221336 | 0 | 0 | 0 | `PASS` |
| 58 | `delay_100k` | `emulator` | `lane3` | `0x00000008` | `0x00000008` | `0x000001FF` | `delay-debug1` | 253331 | 0 | 216864 | 0 | 0 | 0 | `PASS` |
| 59 | `delay_100k` | `emulator` | `lane4` | `0x00000010` | `0x00000010` | `0x000001FF` | `delay-debug1` | 0 | 0 | 223240 | 0 | 0 | 0 | `FAIL` |
| 60 | `delay_100k` | `emulator` | `lane5` | `0x00000020` | `0x00000020` | `0x000001FF` | `delay-debug1` | 0 | 0 | 228464 | 0 | 0 | 0 | `FAIL` |
| 61 | `delay_100k` | `emulator` | `lane6` | `0x00000040` | `0x00000040` | `0x000001FF` | `delay-debug1` | 0 | 0 | 222435 | 0 | 0 | 0 | `FAIL` |
| 62 | `delay_100k` | `emulator` | `lane7` | `0x00000080` | `0x00000080` | `0x000001FF` | `delay-debug1` | 0 | 0 | 226450 | 0 | 0 | 0 | `FAIL` |
| 63 | `delay_100k` | `real` | `all` | `0x000000FF` | `0x00000000` | `0x00000009` | `delay-debug1` | 264528 | 0 | 225651 | 0 | 0 | 0 | `PASS_PARTIAL` |
| 64 | `delay_100k` | `real` | `lane0` | `0x00000001` | `0x00000000` | `0x00000001` | `delay-debug1` | 254819 | 0 | 214416 | 0 | 0 | 0 | `PASS` |
| 65 | `delay_100k` | `real` | `lane1` | `0x00000002` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 66 | `delay_100k` | `real` | `lane2` | `0x00000004` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 67 | `delay_100k` | `real` | `lane3` | `0x00000008` | `0x00000000` | `0x00000008` | `delay-debug1` | 246209 | 0 | 214046 | 0 | 0 | 0 | `PASS` |
| 68 | `delay_100k` | `real` | `lane4` | `0x00000010` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 69 | `delay_100k` | `real` | `lane5` | `0x00000020` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 70 | `delay_100k` | `real` | `lane6` | `0x00000040` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 71 | `delay_100k` | `real` | `lane7` | `0x00000080` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 72 | `delay_100k` | `mixed` | `all` | `0x000000FF` | `0x000000F6` | `0x00000009` | `delay-debug1` | 741106 | 0 | 1538465 | 0 | 0 | 0 | `PASS` |
| 73 | `delay_100k` | `mixed` | `lane0` | `0x00000001` | `0x00000000` | `0x00000001` | `delay-debug1` | 251067 | 0 | 216453 | 0 | 0 | 0 | `PASS` |
| 74 | `delay_100k` | `mixed` | `lane1` | `0x00000002` | `0x00000002` | `0x00000000` | `delay-debug1` | 509649 | 0 | 438865 | 0 | 0 | 0 | `PASS` |
| 75 | `delay_100k` | `mixed` | `lane2` | `0x00000004` | `0x00000004` | `0x00000000` | `delay-debug1` | 481393 | 0 | 427263 | 0 | 0 | 0 | `PASS` |
| 76 | `delay_100k` | `mixed` | `lane3` | `0x00000008` | `0x00000000` | `0x00000008` | `delay-debug1` | 256237 | 0 | 220507 | 0 | 0 | 0 | `PASS` |
| 77 | `delay_100k` | `mixed` | `lane4` | `0x00000010` | `0x00000010` | `0x00000000` | `delay-debug1` | 241251 | 0 | 434389 | 0 | 0 | 0 | `PASS` |
| 78 | `delay_100k` | `mixed` | `lane5` | `0x00000020` | `0x00000020` | `0x00000000` | `delay-debug1` | 268253 | 0 | 446608 | 0 | 0 | 0 | `PASS` |
| 79 | `delay_100k` | `mixed` | `lane6` | `0x00000040` | `0x00000040` | `0x00000000` | `delay-debug1` | 258151 | 0 | 443148 | 0 | 0 | 0 | `PASS` |
| 80 | `delay_100k` | `mixed` | `lane7` | `0x00000080` | `0x00000080` | `0x00000000` | `delay-debug1` | 264174 | 0 | 449363 | 0 | 0 | 0 | `PASS` |
| 81 | `header_1` | `emulator` | `all` | `0x000000FF` | `0x000000FF` | `0x000001FF` | `delay-debug1` | 851124 | 0 | 1465520 | 0 | 0 | 0 | `PASS` |
| 82 | `header_1` | `emulator` | `lane0` | `0x00000001` | `0x00000001` | `0x000001FF` | `delay-debug1` | 196900 | 0 | 172248 | 0 | 0 | 0 | `PASS` |
| 83 | `header_1` | `emulator` | `lane1` | `0x00000002` | `0x00000002` | `0x000001FF` | `delay-debug1` | 0 | 0 | 0 | 0 | 0 | 0 | `FAIL` |
| 84 | `header_1` | `emulator` | `lane2` | `0x00000004` | `0x00000004` | `0x000001FF` | `delay-debug1` | 0 | 0 | 0 | 0 | 0 | 0 | `FAIL` |
| 85 | `header_1` | `emulator` | `lane3` | `0x00000008` | `0x00000008` | `0x000001FF` | `delay-debug1` | 0 | 0 | 0 | 0 | 0 | 0 | `FAIL` |
| 86 | `header_1` | `emulator` | `lane4` | `0x00000010` | `0x00000010` | `0x000001FF` | `delay-debug1` | 0 | 0 | 0 | 0 | 0 | 0 | `FAIL` |
| 87 | `header_1` | `emulator` | `lane5` | `0x00000020` | `0x00000020` | `0x000001FF` | `delay-debug1` | 0 | 0 | 0 | 0 | 0 | 0 | `FAIL` |
| 88 | `header_1` | `emulator` | `lane6` | `0x00000040` | `0x00000040` | `0x000001FF` | `delay-debug1` | 0 | 0 | 0 | 0 | 0 | 0 | `FAIL` |
| 89 | `header_1` | `emulator` | `lane7` | `0x00000080` | `0x00000080` | `0x000001FF` | `delay-debug1` | 0 | 0 | 0 | 0 | 0 | 0 | `FAIL` |
| 90 | `header_1` | `real` | `all` | `0x000000FF` | `0x00000000` | `0x00000009` | `delay-debug1` | 344263 | 0 | 298547 | 0 | 0 | 0 | `PASS_PARTIAL` |
| 91 | `header_1` | `real` | `lane0` | `0x00000001` | `0x00000000` | `0x00000001` | `delay-debug1` | 352938 | 0 | 298422 | 0 | 0 | 0 | `PASS` |
| 92 | `header_1` | `real` | `lane1` | `0x00000002` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 93 | `header_1` | `real` | `lane2` | `0x00000004` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 94 | `header_1` | `real` | `lane3` | `0x00000008` | `0x00000000` | `0x00000008` | `delay-debug1` | 346672 | 0 | 300933 | 0 | 0 | 0 | `PASS` |
| 95 | `header_1` | `real` | `lane4` | `0x00000010` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 96 | `header_1` | `real` | `lane5` | `0x00000020` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 97 | `header_1` | `real` | `lane6` | `0x00000040` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 98 | `header_1` | `real` | `lane7` | `0x00000080` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 99 | `header_1` | `mixed` | `all` | `0x000000FF` | `0x000000F6` | `0x00000009` | `delay-debug1` | 991053 | 0 | 2110698 | 0 | 0 | 0 | `PASS` |
| 100 | `header_1` | `mixed` | `lane0` | `0x00000001` | `0x00000000` | `0x00000001` | `delay-debug1` | 333913 | 0 | 297459 | 0 | 0 | 0 | `PASS` |
| 101 | `header_1` | `mixed` | `lane1` | `0x00000002` | `0x00000002` | `0x00000000` | `delay-debug1` | 663500 | 0 | 597325 | 0 | 0 | 0 | `PASS` |
| 102 | `header_1` | `mixed` | `lane2` | `0x00000004` | `0x00000004` | `0x00000000` | `delay-debug1` | 712190 | 0 | 602530 | 0 | 0 | 0 | `PASS` |
| 103 | `header_1` | `mixed` | `lane3` | `0x00000008` | `0x00000000` | `0x00000008` | `delay-debug1` | 348567 | 0 | 298512 | 0 | 0 | 0 | `PASS` |
| 104 | `header_1` | `mixed` | `lane4` | `0x00000010` | `0x00000010` | `0x00000000` | `delay-debug1` | 338079 | 0 | 599442 | 0 | 0 | 0 | `PASS` |
| 105 | `header_1` | `mixed` | `lane5` | `0x00000020` | `0x00000020` | `0x00000000` | `delay-debug1` | 341354 | 0 | 603715 | 0 | 0 | 0 | `PASS` |
| 106 | `header_1` | `mixed` | `lane6` | `0x00000040` | `0x00000040` | `0x00000000` | `delay-debug1` | 354038 | 0 | 611016 | 0 | 0 | 0 | `PASS` |
| 107 | `header_1` | `mixed` | `lane7` | `0x00000080` | `0x00000080` | `0x00000000` | `delay-debug1` | 341880 | 0 | 607744 | 0 | 0 | 0 | `PASS` |
| 108 | `header_2` | `emulator` | `all` | `0x000000FF` | `0x000000FF` | `0x000001FF` | `delay-debug1` | 1591120 | 0 | 2869168 | 0 | 0 | 0 | `PASS` |
| 109 | `header_2` | `emulator` | `lane0` | `0x00000001` | `0x00000001` | `0x000001FF` | `delay-debug1` | 415868 | 0 | 349654 | 0 | 0 | 0 | `PASS` |
| 110 | `header_2` | `emulator` | `lane1` | `0x00000002` | `0x00000002` | `0x000001FF` | `delay-debug1` | 0 | 0 | 0 | 0 | 0 | 0 | `FAIL` |
| 111 | `header_2` | `emulator` | `lane2` | `0x00000004` | `0x00000004` | `0x000001FF` | `delay-debug1` | 0 | 0 | 0 | 0 | 0 | 0 | `FAIL` |
| 112 | `header_2` | `emulator` | `lane3` | `0x00000008` | `0x00000008` | `0x000001FF` | `delay-debug1` | 0 | 0 | 0 | 0 | 0 | 0 | `FAIL` |
| 113 | `header_2` | `emulator` | `lane4` | `0x00000010` | `0x00000010` | `0x000001FF` | `delay-debug1` | 0 | 0 | 0 | 0 | 0 | 0 | `FAIL` |
| 114 | `header_2` | `emulator` | `lane5` | `0x00000020` | `0x00000020` | `0x000001FF` | `delay-debug1` | 0 | 0 | 0 | 0 | 0 | 0 | `FAIL` |
| 115 | `header_2` | `emulator` | `lane6` | `0x00000040` | `0x00000040` | `0x000001FF` | `delay-debug1` | 0 | 0 | 0 | 0 | 0 | 0 | `FAIL` |
| 116 | `header_2` | `emulator` | `lane7` | `0x00000080` | `0x00000080` | `0x000001FF` | `delay-debug1` | 0 | 0 | 0 | 0 | 0 | 0 | `FAIL` |
| 117 | `header_2` | `real` | `all` | `0x000000FF` | `0x00000000` | `0x00000009` | `delay-debug1` | 694682 | 0 | 600020 | 0 | 0 | 0 | `PASS_PARTIAL` |
| 118 | `header_2` | `real` | `lane0` | `0x00000001` | `0x00000000` | `0x00000001` | `delay-debug1` | 665134 | 0 | 586726 | 0 | 0 | 0 | `PASS` |
| 119 | `header_2` | `real` | `lane1` | `0x00000002` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 120 | `header_2` | `real` | `lane2` | `0x00000004` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 121 | `header_2` | `real` | `lane3` | `0x00000008` | `0x00000000` | `0x00000008` | `delay-debug1` | 677214 | 0 | 592272 | 0 | 0 | 0 | `PASS` |
| 122 | `header_2` | `real` | `lane4` | `0x00000010` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 123 | `header_2` | `real` | `lane5` | `0x00000020` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 124 | `header_2` | `real` | `lane6` | `0x00000040` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 125 | `header_2` | `real` | `lane7` | `0x00000080` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 126 | `header_2` | `mixed` | `all` | `0x000000FF` | `0x000000F6` | `0x00000009` | `delay-debug1` | 1968504 | 0 | 4239578 | 0 | 0 | 0 | `PASS` |
| 127 | `header_2` | `mixed` | `lane0` | `0x00000001` | `0x00000000` | `0x00000001` | `delay-debug1` | 667640 | 0 | 593098 | 0 | 0 | 0 | `PASS` |
| 128 | `header_2` | `mixed` | `lane1` | `0x00000002` | `0x00000002` | `0x00000000` | `delay-debug1` | 1317272 | 0 | 1173814 | 0 | 0 | 0 | `PASS` |
| 129 | `header_2` | `mixed` | `lane2` | `0x00000004` | `0x00000004` | `0x00000000` | `delay-debug1` | 1393302 | 0 | 1182432 | 0 | 0 | 0 | `PASS` |
| 130 | `header_2` | `mixed` | `lane3` | `0x00000008` | `0x00000000` | `0x00000008` | `delay-debug1` | 675698 | 0 | 590782 | 0 | 0 | 0 | `PASS` |
| 131 | `header_2` | `mixed` | `lane4` | `0x00000010` | `0x00000010` | `0x00000000` | `delay-debug1` | 662658 | 0 | 1185294 | 0 | 0 | 0 | `PASS` |
| 132 | `header_2` | `mixed` | `lane5` | `0x00000020` | `0x00000020` | `0x00000000` | `delay-debug1` | 669922 | 0 | 1180356 | 0 | 0 | 0 | `PASS` |
| 133 | `header_2` | `mixed` | `lane6` | `0x00000040` | `0x00000040` | `0x00000000` | `delay-debug1` | 666514 | 0 | 1196350 | 0 | 0 | 0 | `PASS` |
| 134 | `header_2` | `mixed` | `lane7` | `0x00000080` | `0x00000080` | `0x00000000` | `delay-debug1` | 669768 | 0 | 1199898 | 0 | 0 | 0 | `PASS` |
| 135 | `header_4` | `emulator` | `all` | `0x000000FF` | `0x000000FF` | `0x000001FF` | `delay-debug1` | 3202992 | 0 | 5698864 | 0 | 0 | 0 | `PASS` |
| 136 | `header_4` | `emulator` | `lane0` | `0x00000001` | `0x00000001` | `0x000001FF` | `delay-debug1` | 808448 | 0 | 709784 | 0 | 0 | 0 | `PASS` |
| 137 | `header_4` | `emulator` | `lane1` | `0x00000002` | `0x00000002` | `0x000001FF` | `delay-debug1` | 0 | 0 | 0 | 0 | 0 | 0 | `FAIL` |
| 138 | `header_4` | `emulator` | `lane2` | `0x00000004` | `0x00000004` | `0x000001FF` | `delay-debug1` | 0 | 0 | 0 | 0 | 0 | 0 | `FAIL` |
| 139 | `header_4` | `emulator` | `lane3` | `0x00000008` | `0x00000008` | `0x000001FF` | `delay-debug1` | 0 | 0 | 0 | 0 | 0 | 0 | `FAIL` |
| 140 | `header_4` | `emulator` | `lane4` | `0x00000010` | `0x00000010` | `0x000001FF` | `delay-debug1` | 0 | 0 | 0 | 0 | 0 | 0 | `FAIL` |
| 141 | `header_4` | `emulator` | `lane5` | `0x00000020` | `0x00000020` | `0x000001FF` | `delay-debug1` | 0 | 0 | 0 | 0 | 0 | 0 | `FAIL` |
| 142 | `header_4` | `emulator` | `lane6` | `0x00000040` | `0x00000040` | `0x000001FF` | `delay-debug1` | 0 | 0 | 0 | 0 | 0 | 0 | `FAIL` |
| 143 | `header_4` | `emulator` | `lane7` | `0x00000080` | `0x00000080` | `0x000001FF` | `delay-debug1` | 0 | 0 | 0 | 0 | 0 | 0 | `FAIL` |
| 144 | `header_4` | `real` | `all` | `0x000000FF` | `0x00000000` | `0x00000009` | `delay-debug1` | 1430992 | 0 | 1193944 | 0 | 0 | 0 | `PASS_PARTIAL` |
| 145 | `header_4` | `real` | `lane0` | `0x00000001` | `0x00000000` | `0x00000001` | `delay-debug1` | 1388124 | 0 | 1192384 | 0 | 0 | 0 | `PASS` |
| 146 | `header_4` | `real` | `lane1` | `0x00000002` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 147 | `header_4` | `real` | `lane2` | `0x00000004` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 148 | `header_4` | `real` | `lane3` | `0x00000008` | `0x00000000` | `0x00000008` | `delay-debug1` | 1408628 | 0 | 1211160 | 0 | 0 | 0 | `PASS` |
| 149 | `header_4` | `real` | `lane4` | `0x00000010` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 150 | `header_4` | `real` | `lane5` | `0x00000020` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 151 | `header_4` | `real` | `lane6` | `0x00000040` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 152 | `header_4` | `real` | `lane7` | `0x00000080` | `0x00000000` | `0x00000000` | `-` | 0 | 0 | 0 | 0 | 0 | 0 | `BLOCKED` |
| 153 | `header_4` | `mixed` | `all` | `0x000000FF` | `0x000000F6` | `0x00000009` | `delay-debug1` | 4239956 | 0 | 8567520 | 0 | 0 | 0 | `PASS` |
| 154 | `header_4` | `mixed` | `lane0` | `0x00000001` | `0x00000000` | `0x00000001` | `delay-debug1` | 1356848 | 0 | 1195756 | 0 | 0 | 0 | `PASS` |
| 155 | `header_4` | `mixed` | `lane1` | `0x00000002` | `0x00000002` | `0x00000000` | `delay-debug1` | 2732690 | 0 | 2407100 | 0 | 0 | 0 | `PASS` |
| 156 | `header_4` | `mixed` | `lane2` | `0x00000004` | `0x00000004` | `0x00000000` | `delay-debug1` | 2710748 | 0 | 2355900 | 0 | 0 | 0 | `PASS` |
| 157 | `header_4` | `mixed` | `lane3` | `0x00000008` | `0x00000000` | `0x00000008` | `delay-debug1` | 1395936 | 0 | 1188224 | 0 | 0 | 0 | `PASS` |
| 158 | `header_4` | `mixed` | `lane4` | `0x00000010` | `0x00000010` | `0x00000000` | `delay-debug1` | 1351680 | 0 | 2461093 | 0 | 0 | 0 | `PASS` |
| 159 | `header_4` | `mixed` | `lane5` | `0x00000020` | `0x00000020` | `0x00000000` | `delay-debug1` | 1369780 | 0 | 2425852 | 0 | 0 | 0 | `PASS` |
| 160 | `header_4` | `mixed` | `lane6` | `0x00000040` | `0x00000040` | `0x00000000` | `delay-debug1` | 1348848 | 0 | 2396772 | 0 | 0 | 0 | `PASS` |
| 161 | `header_4` | `mixed` | `lane7` | `0x00000080` | `0x00000080` | `0x00000000` | `delay-debug1` | 1350124 | 0 | 2395192 | 0 | 0 | 0 | `PASS` |

## Notes

- `PASS_PARTIAL` means the requested `all` real-MuTRiG scope was reduced to the currently configured real lanes, mask `0x09` by default. It is evidence, but not full eight-MuTRiG closure.
- Delay scenarios use histogram profile `delay-debug1`, i.e. `histogram_statistics_0.CONTROL.mode = -1`, which selects `mts_preprocessor_0.ts_delta` on debug input 1.
- Histogram bin-memory readout is not used by this runner; the current SC path returns `RSP3` on `hist_bin` read/write transactions, so screenshots are CSR/counter evidence until that aperture is debugged.
