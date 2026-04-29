# Phase 5 Injector Datapath Sanity Report

- Timestamp: `2026-04-29T13:19:24`
- SC link: `2`
- Device: `/dev/mudaq0`
- FEB target: `7`
- Source: `emulator`
- Source emulator mask: `0x000000FF`
- LVDS lane-go mask: `0x000001FF`
- Active emulator lanes: `0x00000001`
- Inject mode: `periodic`
- MTS expected latency override: `keep`
- MTS delay-ts field override: `keep`
- MTS drop-delay-error override: `keep`
- Ring filter-inerr override: `keep`
- Result: `FAIL`

## Case Summary

| Case | Run | Source | Mode | Interval | Hist Hits | Hist Drops | MTS Hits | Ring InErr | Real Beats | Emu Beats | Class |
|---:|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | 47000 | `emulator` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 0 | 0 | `exception` |

## Configuration Notes

- The active `mutrig_injector_0` exposes one `coe_inject_pulse` output. The emulator `inject_channel_mask` CSR is still written for visibility, but that mask only affects the separate masked-trigger conduit and is not driven by this injector instance.
- Channel sanity in this report is therefore represented by emulator cluster center/size; ASIC sanity is represented by `active_lanes_mask` and the per-lane source mux selection.
- The runner writes injector mode `0` before setup and immediately after the injection window because the current injector RTL accepts run-control but does not gate the pulse arbiter by RUNNING.

## Per-Case Details

### Case 0

- Run number: `47000`
- Pulse interval: `12500`
- Pulse high cycles: `?`
- Injector mode during run: `?`
- Injector mode after run: `?`
- Lane-go readback: `0x00000000`
- Histogram ingress status: `0x00000000`
- Debug overrides: `{}`
- Source mux selected beat delta: `0`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
- Post-end clean: `no`

- Error: `SC transaction failed after quiet/verbose attempts
quiet rc=4: /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/system_20260427_testplanphase5/bin/sc_tool 2 write 0x08004 0x000001FF --quiet
info: request summary:
  type               : WR
  link               : 2
  addr               : 0x08004
  request length     : 1 word(s)
  main length reg    : 3
  expected reply words (actual)   : 4
  expected reply words (declared) : 4
info: request words written to SC main:
  wmem[0] = 0x1D0002BC
  wmem[1] = 0x00008004
  wmem[2] = 0x00000001
  wmem[3] = 0x000001FF
  wmem[4] = 0x0000009C
  timing main ready   : 59 us
  timing matched      : 0 us
  timing total        : 1034459 us
  secondary before    : 0x0000
  secondary after     : 0x943B
  secondary delta     : 37947 word(s)
  SC main status      : 0x00000001
  SC state            : 0x40000001
warn: skipped non-preamble words while scanning secondary ring
  skipped ring[0x0000] = 0x651E007D
  skipped ring[0x0001] = 0x00FDE813
  skipped ring[0x0002] = 0x0BED80A8
  skipped ring[0x0003] = 0xE01CE960
  skipped ring[0x0004] = 0x00600088
  skipped ring[0x0005] = 0x0620E060
  skipped ring[0x0006] = 0xDBE01EEF
  skipped ring[0x0007] = 0xFEE00EF7
info: packets observed on secondary ring:
  [0] invalid RD_NI link=143 addr=0x3A0F8 rsp=OK ack=0 declared=57474 actual=0 start=0x0077
  [1] invalid RD_NI link=104 addr=0x2809C rsp=OK ack=0 declared=6332 actual=0 start=0x00AE
  [2] invalid RD link=24 addr=0x0FC6F rsp=SLVERR ack=0 declared=61676 actual=0 start=0x00B0
  [3] invalid RD_NI link=227 addr=0x01F07 rsp=OK ack=0 declared=2016 actual=0 start=0x01FF
  [4] invalid WR link=133 addr=0x03F7D rsp=OK ack=1 declared=0 actual=0 start=0x0204
  [5] invalid RD link=224 addr=0x01720 rsp=OK ack=1 declared=32992 actual=0 start=0x021A
  [6] invalid RD link=19 addr=0x0E060 rsp=OK ack=0 declared=64256 actual=0 start=0x0220
  [7] invalid RD_NI link=107 addr=0x07CE4 rsp=RSP3 ack=0 declared=61552 actual=0 start=0x026C
  [8] invalid WR link=32 addr=0x0EFA4 rsp=RSP3 ack=0 declared=34496 actual=0 start=0x031F
  [9] invalid RD_NI link=192 addr=0x25815 rsp=RSP3 ack=0 declared=10109 actual=0 start=0x04A3
  [10] invalid RD_NI link=65 addr=0x00000 rsp=SLVERR ack=1 declared=1792 actual=0 start=0x04C6
  [11] invalid RD link=0 addr=0x38C43 rsp=OK ack=0 declared=23805 actual=0 start=0x0590
  [12] invalid WR link=92 addr=0x10000 rsp=RSP3 ack=0 declared=7232 actual=0 start=0x0592
  [13] invalid RD link=0 addr=0x38C43 rsp=OK ack=0 declared=53472 actual=0 start=0x0597
  [14] invalid WR link=24 addr=0x398E0 rsp=RSP3 ack=0 declared=40992 actual=0 start=0x05A4
  [15] invalid WR link=24 addr=0x398E0 rsp=RSP3 ack=0 declared=40992 actual=0 start=0x05AC
  [16] invalid WR_NI link=124 addr=0x01680 rsp=OK ack=0 declared=53152 actual=0 start=0x05DA
  [17] invalid RD link=67 addr=0x080C1 rsp=RSP3 ack=1 declared=119 actual=0 start=0x06AA
  [18] invalid RD link=255 addr=0x0DC80 rsp=OK ack=0 declared=53088 actual=0 start=0x06B1
  [19] invalid WR link=29 addr=0x0606C rsp=OK ack=1 declared=0 actual=0 start=0x06D0
  [20] invalid WR_NI link=160 addr=0x0E75E rsp=RSP3 ack=1 declared=0 actual=0 start=0x078C
  [21] invalid RD_NI link=224 addr=0x0E000 rsp=RSP3 ack=0 declared=3869 actual=0 start=0x078F
  [22] invalid RD link=23 addr=0x1CD0F rsp=OK ack=0 declared=59232 actual=0 start=0x0804
  [23] invalid RD link=23 addr=0x1CD0F rsp=OK ack=0 declared=59232 actual=0 start=0x080C
  [24] invalid RD link=0 addr=0x312C0 rsp=OK ack=0 declared=112 actual=0 start=0x083D
  [25] invalid WR link=0 addr=0x3F16A rsp=OK ack=0 declared=57503 actual=0 start=0x084D
  [26] invalid WR link=0 addr=0x3F16A rsp=OK ack=0 declared=57503 actual=0 start=0x0855
  [27] invalid WR_NI link=0 addr=0x0E004 rsp=OK ack=0 declared=59395 actual=0 start=0x1183
  [28] invalid WR_NI link=0 addr=0x0E004 rsp=OK ack=0 declared=59395 actual=0 start=0x1189
  [29] invalid WR link=232 addr=0x2177F rsp=OK ack=0 declared=61041 actual=0 start=0x118F
  [30] invalid WR link=241 addr=0x060FE rsp=SLVERR ack=1 declared=0 actual=0 start=0x1295
  [31] invalid WR link=0 addr=0x0E098 rsp=DECERR ack=0 declared=40967 actual=0 start=0x1320
  [32] invalid RD link=64 addr=0x36FE0 rsp=OK ack=0 declared=896 actual=0 start=0x13CF
  [33] invalid WR_NI link=31 addr=0x02018 rsp=OK ack=0 declared=104 actual=0 start=0x2150
  [34] invalid WR_NI link=23 addr=0x03BE3 rsp=OK ack=0 declared=32476 actual=0 start=0x2233
  [35] invalid RD link=224 addr=0x2807F rsp=OK ack=0 declared=32260 actual=0 start=0x231E
  [36] invalid RD_NI link=176 addr=0x2A502 rsp=OK ack=0 declared=37248 actual=0 start=0x2329
  [37] invalid WR link=238 addr=0x00000 rsp=OK ack=0 declared=6496 actual=0 start=0x26B2
  [38] invalid WR link=96 addr=0x10060 rsp=OK ack=1 declared=0 actual=0 start=0x272A
  [39] invalid RD link=127 addr=0x01E9C rsp=OK ack=0 declared=63676 actual=0 start=0x2813
  [40] invalid RD link=248 addr=0x0B840 rsp=SLVERR ack=1 declared=7396 actual=0 start=0x2815
  [41] invalid RD_NI link=181 addr=0x308A0 rsp=RSP3 ack=0 declared=49240 actual=0 start=0x282E
  [42] invalid WR_NI link=39 addr=0x39700 rsp=OK ack=0 declared=53270 actual=0 start=0x286A
  [43] invalid RD_NI link=250 addr=0x0E0E5 rsp=SLVERR ack=1 declared=7124 actual=0 start=0x3F63
  [44] invalid RD link=188 addr=0x0E4E0 rsp=DECERR ack=1 declared=57600 actual=0 start=0x3F98
  [45] invalid WR link=31 addr=0x31DE2 rsp=OK ack=0 declared=6382 actual=0 start=0x4013
  [46] invalid RD link=128 addr=0x33700 rsp=DECERR ack=1 declared=57568 actual=0 start=0x401F
  [47] invalid RD link=160 addr=0x0A0E4 rsp=OK ack=0 declared=13792 actual=0 start=0x40D5
  [48] invalid WR_NI link=13 addr=0x0E0E0 rsp=OK ack=0 declared=6880 actual=0 start=0x426B
  [49] invalid RD link=24 addr=0x00CDB rsp=OK ack=0 declared=57871 actual=0 start=0x42A3
  [50] invalid RD link=96 addr=0x10067 rsp=OK ack=1 declared=4320 actual=0 start=0x4529
  [51] invalid RD link=224 addr=0x0BC31 rsp=RSP3 ack=0 declared=2018 actual=0 start=0x45EA
  [52] invalid RD link=241 addr=0x0E3EE rsp=SLVERR ack=1 declared=28774 actual=0 start=0x4968
  [53] invalid WR link=192 addr=0x3F915 rsp=RSP3 ack=1 declared=0 actual=0 start=0x4996
  [54] invalid RD_NI link=128 addr=0x02820 rsp=OK ack=0 declared=27 actual=0 start=0x49F2
  [55] invalid WR_NI link=0 addr=0x1852E rsp=OK ack=0 declared=480 actual=0 start=0x4A33
  [56] invalid RD_NI link=160 addr=0x0C340 rsp=OK ack=0 declared=59272 actual=0 start=0x4A37
  [57] invalid WR_NI link=44 addr=0x3251E rsp=SLVERR ack=1 declared=0 actual=0 start=0x4A9C
  [58] invalid WR_NI link=24 addr=0x2FE4F rsp=OK ack=0 declared=39008 actual=0 start=0x4B00
  [59] invalid RD link=0 addr=0x0E7E0 rsp=RSP3 ack=1 declared=29184 actual=0 start=0x4B23
  [60] invalid RD link=0 addr=0x0E7E0 rsp=RSP3 ack=1 declared=29184 actual=0 start=0x4B2B
  [61] invalid RD_NI link=0 addr=0x20069 rsp=SLVERR ack=1 declared=189 actual=0 start=0x4C06
  [62] invalid RD_NI link=160 addr=0x00717 rsp=OK ack=0 declared=31840 actual=0 start=0x4C09
  [63] invalid WR link=224 addr=0x0E418 rsp=RSP3 ack=0 declared=25343 actual=0 start=0x4CF4
  [64] invalid RD link=168 addr=0x000F3 rsp=RSP3 ack=1 declared=38952 actual=0 start=0x4D1B
  [65] invalid WR link=156 addr=0x1E065 rsp=OK ack=0 declared=59488 actual=0 start=0x4D1F
  [66] invalid RD link=192 addr=0x100E0 rsp=OK ack=0 declared=59360 actual=0 start=0x4DA2
  [67] invalid RD link=192 addr=0x100E0 rsp=RSP3 ack=0 declared=64992 actual=0 start=0x4DAA
  [68] invalid RD link=100 addr=0x00860 rsp=DECERR ack=1 declared=49310 actual=0 start=0x4DFF
  [69] invalid WR_NI link=192 addr=0x3FF57 rsp=RSP3 ack=0 declared=57536 actual=0 start=0x4E39
  [70] invalid WR_NI link=192 addr=0x3FF57 rsp=RSP3 ack=0 declared=57536 actual=0 start=0x4E41
  [71] invalid WR_NI link=14 addr=0x0D777 rsp=OK ack=0 declared=25088 actual=0 start=0x4E4E
  [72] invalid WR link=30 addr=0x00067 rsp=RSP3 ack=1 declared=0 actual=0 start=0x4F1C
  [73] invalid WR link=30 addr=0x00067 rsp=RSP3 ack=1 declared=0 actual=0 start=0x4F24
  [74] invalid RD link=231 addr=0x040D0 rsp=OK ack=1 declared=0 actual=0 start=0x4FB5
  [75] invalid RD link=231 addr=0x040D0 rsp=OK ack=1 declared=0 actual=0 start=0x4FBC
  [76] invalid WR link=0 addr=0x3FB00 rsp=DECERR ack=0 declared=48352 actual=0 start=0x5557
  [77] invalid WR_NI link=103 addr=0x0B0E0 rsp=DECERR ack=1 declared=0 actual=0 start=0x556E
  [78] invalid WR link=204 addr=0x0E000 rsp=OK ack=0 declared=56571 actual=0 start=0x59B0
  [79] invalid RD link=160 addr=0x000C2 rsp=RSP3 ack=0 declared=62080 actual=0 start=0x5A53
  [80] invalid RD_NI link=186 addr=0x3E9E0 rsp=DECERR ack=0 declared=60128 actual=0 start=0x5A5A
  [81] invalid WR_NI link=224 addr=0x11903 rsp=OK ack=0 declared=39183 actual=0 start=0x5AF9
  [82] invalid RD_NI link=27 addr=0x00060 rsp=RSP3 ack=1 declared=35072 actual=0 start=0x5B59
  [83] invalid WR link=194 addr=0x108EC rsp=DECERR ack=1 declared=0 actual=0 start=0x5E79
  [84] invalid RD_NI link=0 addr=0x0E712 rsp=OK ack=0 declared=64736 actual=0 start=0x62E1
  [85] invalid RD link=148 addr=0x0601E rsp=RSP3 ack=1 declared=5888 actual=0 start=0x630A
  [86] invalid RD link=148 addr=0x0601E rsp=RSP3 ack=1 declared=5888 actual=0 start=0x6312
  [87] invalid RD_NI link=30 addr=0x00009 rsp=SLVERR ack=1 declared=65152 actual=0 start=0x683D
  [88] invalid RD_NI link=0 addr=0x00080 rsp=RSP3 ack=0 declared=57454 actual=0 start=0x6851
  [89] invalid WR_NI link=5 addr=0x240D3 rsp=OK ack=1 declared=0 actual=0 start=0x898D
  [90] invalid WR link=16 addr=0x30018 rsp=DECERR ack=0 declared=57344 actual=0 start=0x8B44
  [91] invalid RD link=15 addr=0x187FC rsp=DECERR ack=1 declared=3680 actual=0 start=0x905E
  [92] invalid RD_NI link=135 addr=0x30E60 rsp=SLVERR ack=1 declared=31712 actual=0 start=0x905F
  [93] invalid RD link=15 addr=0x187FC rsp=DECERR ack=1 declared=3680 actual=0 start=0x9066
  [94] invalid RD_NI link=135 addr=0x30E60 rsp=SLVERR ack=1 declared=31712 actual=0 start=0x9067
  [95] invalid RD_NI link=0 addr=0x30063 rsp=RSP3 ack=0 declared=6423 actual=0 start=0x9289
  [96] invalid WR link=93 addr=0x2F7F8 rsp=OK ack=0 declared=57984 actual=0 start=0x92A2
  [97] invalid RD_NI link=252 addr=0x300E7 rsp=OK ack=0 declared=15584 actual=0 start=0x92F4
  [98] invalid RD_NI link=224 addr=0x00702 rsp=OK ack=0 declared=63260 actual=0 start=0x93FA
  [99] invalid RD link=234 addr=0x040E3 rsp=OK ack=0 declared=8160 actual=0 start=0x941E
warn: scan ended with an incomplete candidate packet
err: timed out waiting for matching secondary reply

verbose rc=4: /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/system_20260427_testplanphase5/bin/sc_tool 2 write 0x08004 0x000001FF
board:
  PLL_LOCKED_REGISTER_R      = 0x00000000
  LINK_LOCKED_LOW_REGISTER_R = 0x31000000
  LINK_LOCKED_HIGH_REGISTER_R= 0x00000F00
  RESET_LINK_STATUS_REGISTER_R = 0x00000000
info: request summary:
  type               : WR
  link               : 2
  addr               : 0x08004
  request length     : 1 word(s)
  main length reg    : 3
  expected reply words (actual)   : 4
  expected reply words (declared) : 4
info: request words written to SC main:
  wmem[0] = 0x1D0002BC
  wmem[1] = 0x00008004
  wmem[2] = 0x00000001
  wmem[3] = 0x000001FF
  wmem[4] = 0x0000009C
  timing main ready   : 58 us
  timing matched      : 0 us
  timing total        : 1015063 us
  secondary before    : 0x006E
  secondary after     : 0xE61E
  secondary delta     : 58800 word(s)
  SC main status      : 0x00000001
  SC state            : 0x40000001
warn: skipped non-preamble words while scanning secondary ring
  skipped ring[0x006E] = 0x00150080
  skipped ring[0x006F] = 0xF80C07E0
  skipped ring[0x0070] = 0xE38085E7
  skipped ring[0x0071] = 0x7CE26808
  skipped ring[0x0072] = 0x4067F2B8
  skipped ring[0x0073] = 0x786AF1E0
  skipped ring[0x0074] = 0x80F08307
  skipped ring[0x0075] = 0xEC7D1127
info: packets observed on secondary ring:
  [0] invalid WR_NI link=126 addr=0x0E0A0 rsp=OK ack=0 declared=49159 actual=0 start=0x01DA
  [1] invalid RD link=248 addr=0x0E0EE rsp=OK ack=0 declared=57353 actual=0 start=0x01E8
  [2] invalid RD_NI link=24 addr=0x1EA18 rsp=DECERR ack=0 declared=57373 actual=0 start=0x0212
  [3] invalid RD link=6 addr=0x06900 rsp=SLVERR ack=0 declared=32792 actual=0 start=0x023C
  [4] invalid RD link=6 addr=0x06900 rsp=SLVERR ack=0 declared=32792 actual=0 start=0x0244
  [5] invalid WR_NI link=242 addr=0x0F360 rsp=OK ack=0 declared=62464 actual=0 start=0x0318
  [6] invalid RD_NI link=224 addr=0x0041A rsp=DECERR ack=1 declared=0 actual=0 start=0x0324
  [7] invalid RD_NI link=8 addr=0x31C61 rsp=SLVERR ack=0 declared=61691 actual=0 start=0x032C
  [8] invalid WR link=224 addr=0x0E0E0 rsp=RSP3 ack=1 declared=0 actual=0 start=0x038A
  [9] invalid WR link=224 addr=0x0E0E0 rsp=OK ack=0 declared=49920 actual=0 start=0x0391
  [10] invalid RD_NI link=15 addr=0x0E01B rsp=OK ack=0 declared=31076 actual=0 start=0x03D5
  [11] invalid RD link=224 addr=0x3E000 rsp=OK ack=0 declared=6284 actual=0 start=0x0425
  [12] invalid RD link=160 addr=0x1E498 rsp=RSP3 ack=1 declared=125 actual=0 start=0x1FCC
  [13] invalid WR link=145 addr=0x0F760 rsp=SLVERR ack=1 declared=0 actual=0 start=0x2054
  [14] invalid WR link=145 addr=0x0F760 rsp=SLVERR ack=1 declared=0 actual=0 start=0x205B
  [15] invalid WR_NI link=0 addr=0x1F21E rsp=SLVERR ack=1 declared=0 actual=0 start=0x23DA
  [16] invalid RD link=226 addr=0x00000 rsp=OK ack=0 declared=128 actual=0 start=0x23FD
  [17] invalid RD link=0 addr=0x3ED00 rsp=OK ack=0 declared=12033 actual=0 start=0x2415
  [18] invalid RD_NI link=224 addr=0x0E080 rsp=DECERR ack=1 declared=60768 actual=0 start=0x2430
  [19] invalid RD_NI link=239 addr=0x3C0E0 rsp=OK ack=0 declared=8295 actual=0 start=0x2436
  [20] invalid RD link=16 addr=0x080E8 rsp=RSP3 ack=0 declared=63558 actual=0 start=0x26AA
  [21] invalid WR link=96 addr=0x00700 rsp=OK ack=0 declared=15612 actual=0 start=0x29AE
  [22] invalid RD_NI link=21 addr=0x3EC9C rsp=OK ack=1 declared=5564 actual=0 start=0x29CE
  [23] invalid RD_NI link=21 addr=0x3EC9C rsp=RSP3 ack=1 declared=61116 actual=0 start=0x29D0
  [24] invalid RD link=238 addr=0x3A000 rsp=RSP3 ack=0 declared=254 actual=0 start=0x29D2
  [25] invalid RD link=183 addr=0x010E1 rsp=SLVERR ack=0 declared=24768 actual=0 start=0x2A2D
  [26] invalid RD link=183 addr=0x010E1 rsp=SLVERR ack=0 declared=24768 actual=0 start=0x2A33
  [27] invalid WR_NI link=87 addr=0x0F514 rsp=OK ack=0 declared=224 actual=0 start=0x2A3D
  [28] invalid WR link=0 addr=0x017E0 rsp=OK ack=1 declared=0 actual=0 start=0x2CEC
  [29] invalid RD link=247 addr=0x0E001 rsp=OK ack=0 declared=58112 actual=0 start=0x2D08
  [30] invalid RD_NI link=7 addr=0x060E0 rsp=OK ack=0 declared=58264 actual=0 start=0x2D0D
  [31] invalid RD_NI link=7 addr=0x060E0 rsp=OK ack=0 declared=6910 actual=0 start=0x2D14
  [32] invalid RD link=26 addr=0x35CEF rsp=DECERR ack=0 declared=770 actual=0 start=0x2D16
  [33] invalid WR_NI link=224 addr=0x312C0 rsp=SLVERR ack=1 declared=0 actual=0 start=0x2EDE
  [34] invalid RD_NI link=0 addr=0x02000 rsp=OK ack=0 declared=57405 actual=0 start=0x2F46
  [35] invalid RD_NI link=120 addr=0x00061 rsp=OK ack=0 declared=118 actual=0 start=0x2F9C
  [36] invalid RD link=248 addr=0x0E0E7 rsp=OK ack=0 declared=99 actual=0 start=0x3041
  [37] invalid RD link=0 addr=0x0F000 rsp=OK ack=0 declared=40847 actual=0 start=0x3050
  [38] invalid RD link=172 addr=0x00087 rsp=DECERR ack=1 declared=57569 actual=0 start=0x30B7
  [39] invalid RD_NI link=160 addr=0x35AC0 rsp=OK ack=0 declared=58880 actual=0 start=0x3174
  [40] invalid RD link=0 addr=0x0E0BC rsp=SLVERR ack=0 declared=17118 actual=0 start=0x31B0
  [41] invalid RD_NI link=224 addr=0x10560 rsp=DECERR ack=0 declared=61472 actual=0 start=0x320C
  [42] invalid WR link=228 addr=0x08774 rsp=RSP3 ack=0 declared=56551 actual=0 start=0x3260
  [43] invalid RD link=64 addr=0x07808 rsp=DECERR ack=0 declared=57344 actual=0 start=0x32BC
  [44] invalid RD_NI link=157 addr=0x00000 rsp=OK ack=0 declared=24675 actual=0 start=0x33BC
  [45] invalid RD_NI link=96 addr=0x08011 rsp=SLVERR ack=1 declared=4870 actual=0 start=0x3467
  [46] invalid WR_NI link=233 addr=0x0A0E0 rsp=OK ack=0 declared=24800 actual=0 start=0x3605
  [47] invalid WR_NI link=233 addr=0x0A0E0 rsp=OK ack=0 declared=24800 actual=0 start=0x360D
  [48] invalid WR link=7 addr=0x0000F rsp=OK ack=0 declared=4252 actual=0 start=0x365A
  [49] invalid WR link=7 addr=0x0000F rsp=OK ack=0 declared=4252 actual=0 start=0x365D
  [50] invalid RD link=100 addr=0x10400 rsp=DECERR ack=1 declared=7046 actual=0 start=0x3660
  [51] invalid RD link=100 addr=0x10400 rsp=DECERR ack=1 declared=7046 actual=0 start=0x3668
  [52] invalid WR link=54 addr=0x3E018 rsp=OK ack=0 declared=57472 actual=0 start=0x36DE
  [53] invalid RD_NI link=0 addr=0x0A080 rsp=DECERR ack=0 declared=5285 actual=0 start=0x36E6
  [54] invalid RD link=254 addr=0x2E080 rsp=RSP3 ack=0 declared=1504 actual=0 start=0x3708
  [55] invalid RD link=254 addr=0x2E080 rsp=RSP3 ack=0 declared=1504 actual=0 start=0x3710
  [56] invalid RD_NI link=96 addr=0x01CFB rsp=OK ack=0 declared=57344 actual=0 start=0x37BB
  [57] invalid RD_NI link=96 addr=0x01CFB rsp=OK ack=0 declared=57344 actual=0 start=0x37C3
  [58] invalid WR_NI link=136 addr=0x001E0 rsp=OK ack=0 declared=2043 actual=0 start=0x380C
  [59] invalid RD link=0 addr=0x060DF rsp=OK ack=0 declared=64832 actual=0 start=0x3848
  [60] invalid RD_NI link=12 addr=0x00060 rsp=OK ack=0 declared=63970 actual=0 start=0x52CB
  [61] invalid RD link=176 addr=0x0E858 rsp=SLVERR ack=1 declared=57367 actual=0 start=0x52DD
  [62] invalid WR_NI link=14 addr=0x18AA0 rsp=SLVERR ack=1 declared=0 actual=0 start=0x53F3
  [63] invalid RD_NI link=40 addr=0x314E0 rsp=OK ack=0 declared=57348 actual=0 start=0x53F6
  [64] invalid RD_NI link=40 addr=0x314E0 rsp=OK ack=0 declared=57348 actual=0 start=0x53FE
  [65] invalid RD_NI link=253 addr=0x0789E rsp=SLVERR ack=0 declared=6656 actual=0 start=0x544F
  [66] invalid RD_NI link=253 addr=0x0789E rsp=SLVERR ack=0 declared=6656 actual=0 start=0x5457
  [67] invalid RD link=189 addr=0x3B81F rsp=DECERR ack=0 declared=64 actual=0 start=0x743C
  [68] invalid RD link=189 addr=0x11B10 rsp=DECERR ack=0 declared=59360 actual=0 start=0x7443
  [69] invalid RD link=96 addr=0x07CE8 rsp=OK ack=0 declared=32 actual=0 start=0x745C
  [70] invalid RD_NI link=248 addr=0x06710 rsp=RSP3 ack=1 declared=16401 actual=0 start=0x7BCF
  [71] invalid WR link=7 addr=0x321E0 rsp=SLVERR ack=0 declared=41152 actual=0 start=0x7BEC
  [72] invalid RD_NI link=19 addr=0x0FC80 rsp=OK ack=0 declared=864 actual=0 start=0x7C7A
  [73] invalid RD link=224 addr=0x219FC rsp=RSP3 ack=1 declared=55010 actual=0 start=0x7D8C
  [74] invalid RD link=224 addr=0x219FC rsp=RSP3 ack=1 declared=55010 actual=0 start=0x7D94
  [75] invalid RD link=140 addr=0x0C0EE rsp=RSP3 ack=0 declared=252 actual=0 start=0x81A8
  [76] invalid WR link=231 addr=0x09880 rsp=OK ack=0 declared=4832 actual=0 start=0x81DB
  [77] invalid WR link=24 addr=0x0E080 rsp=OK ack=0 declared=65022 actual=0 start=0x8374
  [78] invalid WR link=224 addr=0x000E0 rsp=SLVERR ack=0 declared=64736 actual=0 start=0x8463
  [79] invalid WR_NI link=192 addr=0x000A0 rsp=OK ack=0 declared=65340 actual=0 start=0x854B
  [80] invalid RD_NI link=211 addr=0x11EF1 rsp=OK ack=0 declared=57368 actual=0 start=0x8554
  [81] invalid WR link=132 addr=0x020E0 rsp=DECERR ack=1 declared=0 actual=0 start=0x86A8
  [82] invalid WR link=1 addr=0x01C00 rsp=SLVERR ack=0 declared=58592 actual=0 start=0x8994
  [83] invalid WR link=242 addr=0x0972E rsp=RSP3 ack=1 declared=0 actual=0 start=0x8A9A
  [84] invalid RD link=64 addr=0x30080 rsp=OK ack=0 declared=92 actual=0 start=0x8AD0
  [85] invalid WR_NI link=0 addr=0x0FE40 rsp=OK ack=0 declared=57368 actual=0 start=0x8B95
  [86] invalid RD link=105 addr=0x008E6 rsp=RSP3 ack=1 declared=49183 actual=0 start=0x8DB1
  [87] invalid RD link=192 addr=0x200EF rsp=DECERR ack=0 declared=8786 actual=0 start=0x8DBF
  [88] invalid RD link=192 addr=0x200EF rsp=DECERR ack=0 declared=8786 actual=0 start=0x8DC7
  [89] invalid RD link=124 addr=0x018BD rsp=RSP3 ack=0 declared=7151 actual=0 start=0x8FAB
  [90] invalid RD_NI link=144 addr=0x2E418 rsp=RSP3 ack=0 declared=6311 actual=0 start=0x9006
  [91] invalid RD_NI link=4 addr=0x3401E rsp=OK ack=0 declared=57369 actual=0 start=0x9065
  [92] invalid WR link=248 addr=0x20414 rsp=OK ack=0 declared=122 actual=0 start=0x90E0
  [93] invalid WR link=248 addr=0x20414 rsp=OK ack=0 declared=6392 actual=0 start=0x90E8
  [94] invalid RD link=0 addr=0x05540 rsp=SLVERR ack=0 declared=41195 actual=0 start=0x9145
  [95] invalid WR_NI link=7 addr=0x01700 rsp=OK ack=0 declared=39162 actual=0 start=0x9171
  [96] invalid WR_NI link=7 addr=0x01700 rsp=OK ack=0 declared=39162 actual=0 start=0x9179
  [97] invalid RD_NI link=224 addr=0x01CE0 rsp=OK ack=0 declared=63965 actual=0 start=0x91A3
  [98] invalid RD link=30 addr=0x01BCD rsp=OK ack=0 declared=96 actual=0 start=0x94B1
  [99] invalid RD link=30 addr=0x01BCD rsp=OK ack=0 declared=96 actual=0 start=0x94B9
  [100] invalid RD_NI link=20 addr=0x0C087 rsp=SLVERR ack=0 declared=33863 actual=0 start=0x94CF
  [101] invalid RD link=231 addr=0x27460 rsp=RSP3 ack=0 declared=18208 actual=0 start=0x9520
  [102] invalid WR_NI link=154 addr=0x2FCE0 rsp=RSP3 ack=1 declared=0 actual=0 start=0x9806
  [103] invalid RD link=56 addr=0x140E0 rsp=OK ack=0 declared=16583 actual=0 start=0x985F
  [104] invalid RD link=56 addr=0x073E0 rsp=OK ack=1 declared=57345 actual=0 start=0x9866
  [105] invalid WR_NI link=224 addr=0x3EE87 rsp=RSP3 ack=1 declared=0 actual=0 start=0x989A
  [106] invalid RD_NI link=96 addr=0x01460 rsp=OK ack=1 declared=104 actual=0 start=0x990C
  [107] invalid RD_NI link=96 addr=0x01460 rsp=OK ack=1 declared=104 actual=0 start=0x9913
  [108] invalid WR link=8 addr=0x007E0 rsp=RSP3 ack=0 declared=30176 actual=0 start=0x9946
  [109] invalid RD_NI link=96 addr=0x0FAE8 rsp=DECERR ack=0 declared=57585 actual=0 start=0x9CB9
  [110] invalid RD_NI link=0 addr=0x00E60 rsp=OK ack=1 declared=2079 actual=0 start=0x9CC7
  [111] invalid RD_NI link=8 addr=0x1BDFA rsp=DECERR ack=0 declared=54112 actual=0 start=0x9CF9
  [112] invalid WR link=224 addr=0x2EB20 rsp=OK ack=0 declared=57442 actual=0 start=0x9D49
  [113] invalid RD link=144 addr=0x0EBE0 rsp=DECERR ack=0 declared=30222 actual=0 start=0x9D9B
  [114] invalid RD link=144 addr=0x0EBE0 rsp=DECERR ack=0 declared=30222 actual=0 start=0x9DA3
  [115] invalid RD_NI link=243 addr=0x20000 rsp=OK ack=0 declared=40968 actual=0 start=0x9F98
  [116] invalid RD_NI link=243 addr=0x20000 rsp=OK ack=0 declared=40968 actual=0 start=0x9FA0
  [117] invalid RD_NI link=224 addr=0x180C1 rsp=OK ack=0 declared=34699 actual=0 start=0xA08A
  [118] invalid WR link=231 addr=0x0FCBC rsp=OK ack=0 declared=9246 actual=0 start=0xA144
  [119] invalid WR link=231 addr=0x0FCBC rsp=OK ack=0 declared=9246 actual=0 start=0xA14C
  [120] invalid WR link=96 addr=0x00EE0 rsp=OK ack=0 declared=26744 actual=0 start=0xA15D
  [121] invalid RD_NI link=243 addr=0x00000 rsp=RSP3 ack=0 declared=61408 actual=0 start=0xA1A5
  [122] invalid WR link=224 addr=0x0FD00 rsp=SLVERR ack=1 declared=0 actual=0 start=0xA263
  [123] invalid WR link=224 addr=0x0FD00 rsp=SLVERR ack=1 declared=0 actual=0 start=0xA26B
  [124] invalid RD link=64 addr=0x196E7 rsp=OK ack=1 declared=40960 actual=0 start=0xA2F9
  [125] invalid WR link=231 addr=0x0C074 rsp=DECERR ack=1 declared=0 actual=0 start=0xA37C
  [126] invalid RD link=102 addr=0x2DC98 rsp=SLVERR ack=0 declared=8224 actual=0 start=0xA3A4
  [127] invalid RD link=102 addr=0x2DC98 rsp=RSP3 ack=0 declared=32 actual=0 start=0xA3AC
  [128] invalid RD link=166 addr=0x0007A rsp=OK ack=0 declared=224 actual=0 start=0xA3CC
  [129] invalid RD link=7 addr=0x30C00 rsp=RSP3 ack=0 declared=59264 actual=0 start=0xA41D
  [130] invalid RD link=233 addr=0x06031 rsp=SLVERR ack=1 declared=12007 actual=0 start=0xA426
  [131] invalid RD link=224 addr=0x160BE rsp=OK ack=0 declared=41088 actual=0 start=0xA42D
  [132] invalid WR link=177 addr=0x2A7E7 rsp=OK ack=0 declared=24576 actual=0 start=0xA482
  [133] invalid WR link=0 addr=0x0EF10 rsp=DECERR ack=1 declared=0 actual=0 start=0xA4EF
  [134] invalid WR_NI link=224 addr=0x3E0E0 rsp=SLVERR ack=1 declared=0 actual=0 start=0xA571
  [135] invalid RD_NI link=224 addr=0x29260 rsp=RSP3 ack=1 declared=24809 actual=0 start=0xA57B
  [136] invalid RD_NI link=224 addr=0x29260 rsp=RSP3 ack=1 declared=24809 actual=0 start=0xA583
  [137] invalid WR link=209 addr=0x0C000 rsp=OK ack=0 declared=763 actual=0 start=0xA62E
  [138] invalid RD link=250 addr=0x0E0E0 rsp=SLVERR ack=1 declared=237 actual=0 start=0xA673
  [139] invalid RD link=250 addr=0x0E0E0 rsp=SLVERR ack=1 declared=237 actual=0 start=0xA67B
  [140] invalid RD_NI link=224 addr=0x2E07E rsp=OK ack=0 declared=59012 actual=0 start=0xAB17
  [141] invalid RD_NI link=224 addr=0x21DE4 rsp=DECERR ack=0 declared=3277 actual=0 start=0xAB1A
  [142] invalid WR link=227 addr=0x1F01F rsp=OK ack=0 declared=36352 actual=0 start=0xABED
  [143] invalid WR link=1 addr=0x182F8 rsp=SLVERR ack=0 declared=48126 actual=0 start=0xAC5E
  [144] invalid WR_NI link=0 addr=0x0F877 rsp=OK ack=0 declared=519 actual=0 start=0xAC6A
  [145] invalid WR link=24 addr=0x1C0C6 rsp=OK ack=0 declared=64704 actual=0 start=0xAC95
  [146] invalid WR_NI link=28 addr=0x0661B rsp=OK ack=0 declared=2313 actual=0 start=0xB043
  [147] invalid WR_NI link=7 addr=0x0806E rsp=OK ack=0 declared=32952 actual=0 start=0xB0F3
  [148] invalid RD link=192 addr=0x3FCC0 rsp=OK ack=1 declared=7968 actual=0 start=0xB12F
  [149] invalid RD link=192 addr=0x3FCC0 rsp=OK ack=1 declared=7968 actual=0 start=0xB136
  [150] invalid RD link=98 addr=0x000A4 rsp=RSP3 ack=0 declared=32796 actual=0 start=0xB14A
  [151] invalid RD_NI link=233 addr=0x1DC60 rsp=OK ack=0 declared=57472 actual=0 start=0xB2F4
  [152] invalid RD link=28 addr=0x31015 rsp=OK ack=0 declared=224 actual=0 start=0xB364
  [153] invalid RD link=124 addr=0x2F2FD rsp=DECERR ack=1 declared=31884 actual=0 start=0xB41E
  [154] invalid RD_NI link=237 addr=0x06D8D rsp=RSP3 ack=1 declared=21375 actual=0 start=0xB46A
  [155] invalid RD_NI link=0 addr=0x361BC rsp=OK ack=0 declared=0 actual=0 start=0xB48F
  [156] invalid RD link=146 addr=0x0C011 rsp=OK ack=0 declared=57472 actual=0 start=0xB4E4
  [157] invalid WR_NI link=8 addr=0x01B00 rsp=OK ack=0 declared=24704 actual=0 start=0xB4FC
  [158] invalid WR_NI link=249 addr=0x0E01A rsp=DECERR ack=1 declared=0 actual=0 start=0xB64D
  [159] invalid WR_NI link=249 addr=0x3E0E7 rsp=RSP3 ack=0 declared=8207 actual=0 start=0xB653
  [160] invalid RD_NI link=96 addr=0x3F500 rsp=DECERR ack=0 declared=6976 actual=0 start=0xB67A
  [161] invalid WR link=224 addr=0x38007 rsp=OK ack=0 declared=61464 actual=0 start=0xB780
  [162] invalid WR link=224 addr=0x004E0 rsp=OK ack=0 declared=24 actual=0 start=0xB79F
  [163] invalid WR link=224 addr=0x004E0 rsp=OK ack=0 declared=24 actual=0 start=0xB7A7
  [164] invalid WR link=0 addr=0x260C0 rsp=RSP3 ack=0 declared=55776 actual=0 start=0xB830
  [165] invalid RD link=96 addr=0x1E0EB rsp=OK ack=0 declared=14244 actual=0 start=0xB838
  [166] invalid RD_NI link=15 addr=0x0E000 rsp=OK ack=0 declared=1248 actual=0 start=0xBAEA
  [167] invalid RD_NI link=15 addr=0x0E000 rsp=RSP3 ack=0 declared=7136 actual=0 start=0xBAF2
  [168] invalid WR_NI link=17 addr=0x36080 rsp=OK ack=0 declared=33981 actual=0 start=0xBB71
  [169] invalid WR_NI link=7 addr=0x00FEE rsp=SLVERR ack=1 declared=0 actual=0 start=0xBCBE
  [170] invalid WR_NI link=7 addr=0x00FEE rsp=SLVERR ack=1 declared=0 actual=0 start=0xBCC5
  [171] invalid RD link=128 addr=0x008B7 rsp=OK ack=0 declared=227 actual=0 start=0xBCE2
  [172] invalid WR_NI link=16 addr=0x186BC rsp=OK ack=0 declared=2656 actual=0 start=0xC0A5
  [173] invalid RD link=134 addr=0x00A60 rsp=OK ack=0 declared=7904 actual=0 start=0xC0A6
  [174] invalid WR_NI link=32 addr=0x2BC08 rsp=RSP3 ack=1 declared=0 actual=0 start=0xC1DB
  [175] invalid RD link=36 addr=0x113D2 rsp=RSP3 ack=0 declared=31488 actual=0 start=0xC234
  [176] invalid RD link=36 addr=0x113D2 rsp=RSP3 ack=0 declared=31488 actual=0 start=0xC23C
  [177] invalid RD_NI link=224 addr=0x36060 rsp=OK ack=0 declared=49248 actual=0 start=0xC501
  [178] invalid RD link=13 addr=0x065E0 rsp=SLVERR ack=1 declared=40976 actual=0 start=0xE2E0
  [179] invalid WR_NI link=224 addr=0x0F000 rsp=SLVERR ack=1 declared=0 actual=0 start=0xE2E5
  [180] invalid WR_NI link=224 addr=0x0F000 rsp=SLVERR ack=1 declared=0 actual=0 start=0xE2E8
  [181] invalid RD link=116 addr=0x0E0EB rsp=OK ack=0 declared=2242 actual=0 start=0xE2EB
  [182] invalid WR_NI link=32 addr=0x3E0A8 rsp=RSP3 ack=0 declared=14463 actual=0 start=0xE32B
  [183] invalid WR_NI link=32 addr=0x3E0A8 rsp=RSP3 ack=0 declared=14463 actual=0 start=0xE333
  [184] invalid WR_NI link=248 addr=0x0008F rsp=OK ack=0 declared=59360 actual=0 start=0xE3F1
  [185] invalid WR_NI link=248 addr=0x0008F rsp=OK ack=0 declared=59360 actual=0 start=0xE3F8
  [186] invalid WR link=254 addr=0x068C0 rsp=RSP3 ack=0 declared=57344 actual=0 start=0xE467
  [187] invalid RD_NI link=224 addr=0x011E7 rsp=RSP3 ack=1 declared=58003 actual=0 start=0xE491
  [188] invalid RD_NI link=108 addr=0x0FE8F rsp=OK ack=0 declared=63404 actual=0 start=0xE510
  [189] invalid RD_NI link=60 addr=0x00087 rsp=SLVERR ack=0 declared=57585 actual=0 start=0xE54D
warn: scan ended with an incomplete candidate packet
err: timed out waiting for matching secondary reply
`

