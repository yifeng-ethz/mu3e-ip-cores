# Phase 5 Injector Datapath Sanity Report

- Timestamp: `2026-04-29T19:33:52`
- SC link: `2`
- Device: `/dev/mudaq0`
- FEB target: `7`
- Source: `real`
- Source emulator mask: `0x00000000`
- LVDS lane-go mask: `0x00000009`
- Active emulator lanes: `0x00000000`
- Inject mode: `periodic`
- Histogram profile: `rate`
- Histogram filter enable: `True`
- Histogram filter key loc override: `None`
- Histogram filter key value: `0x00000010`
- MTS expected latency override: `keep`
- MTS delay-ts field override: `keep`
- MTS drop-delay-error override: `keep`
- Ring filter-inerr override: `keep`
- Result: `FAIL`

## Case Summary

| Case | Run | Source | Mode | Interval | Hist Hits | Hist Drops | MTS Hits | Ring InErr | Real Beats | Emu Beats | Class |
|---:|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | 49200 | `real` | `periodic` | 1250 | 0 | 0 | 0 | 0 | 0 | 0 | `exception` |

## Configuration Notes

- The active `mutrig_injector_0` exposes one `coe_inject_pulse` output. The emulator `inject_channel_mask` CSR is still written for visibility, but that mask only affects the separate masked-trigger conduit and is not driven by this injector instance.
- Channel sanity in this report is therefore represented by emulator cluster center/size; ASIC sanity is represented by `active_lanes_mask` and the per-lane source mux selection.
- The runner writes injector mode `0` before setup and immediately after the injection window because the current injector RTL accepts run-control but does not gate the pulse arbiter by RUNNING.

## Per-Case Details

### Case 0

- Run number: `49200`
- Pulse interval: `1250`
- Pulse high cycles: `?`
- Injector mode during run: `?`
- Injector mode after run: `?`
- Lane-go readback: `0x00000000`
- Histogram ingress status: `0x00000000`
- Histogram profile/readback: `{}`
- Debug overrides: `{}`
- Source mux selected beat delta: `0`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
- Post-end clean: `no`

- Error: `SC transaction failed after quiet/verbose attempts
quiet rc=4: /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/system_20260427_testplanphase5/bin/sc_tool 2 write 0x08004 0x00000009 --quiet
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
  wmem[3] = 0x00000009
  wmem[4] = 0x0000009C
  timing main ready   : 58 us
  timing matched      : 0 us
  timing total        : 1005670 us
  secondary before    : 0x00A0
  secondary after     : 0x6AAE
  secondary delta     : 27150 word(s)
  SC main status      : 0x00000001
  SC state            : 0x40000001
warn: skipped non-preamble words while scanning secondary ring
  skipped ring[0x00A0] = 0x00000000
  skipped ring[0x00A1] = 0x00000000
  skipped ring[0x00A2] = 0x00000000
  skipped ring[0x00A3] = 0x00000000
  skipped ring[0x00A4] = 0x00000000
  skipped ring[0x00A5] = 0x00000000
  skipped ring[0x00A6] = 0x00000000
  skipped ring[0x00A7] = 0x00000000
info: packets observed on secondary ring:
  [0] invalid WR_NI link=188 addr=0x0801D rsp=SLVERR ack=0 declared=38599 actual=0 start=0x181F
  [1] invalid RD_NI link=5 addr=0x0E803 rsp=OK ack=0 declared=59240 actual=0 start=0x18E9
  [2] invalid WR_NI link=0 addr=0x000E3 rsp=OK ack=1 declared=0 actual=0 start=0x190F
  [3] invalid RD link=224 addr=0x0A03C rsp=RSP3 ack=1 declared=59164 actual=0 start=0x1CEB
  [4] invalid WR link=224 addr=0x20607 rsp=RSP3 ack=1 declared=0 actual=0 start=0x2310
  [5] invalid WR link=17 addr=0x0001E rsp=OK ack=0 declared=62070 actual=0 start=0x23BA
  [6] invalid RD_NI link=96 addr=0x3E0E1 rsp=OK ack=1 declared=224 actual=0 start=0x240B
  [7] invalid WR_NI link=224 addr=0x000E4 rsp=RSP3 ack=0 declared=39328 actual=0 start=0x24C0
  [8] invalid RD link=149 addr=0x2EA00 rsp=DECERR ack=1 declared=57568 actual=0 start=0x2515
  [9] invalid WR_NI link=224 addr=0x00094 rsp=OK ack=0 declared=240 actual=0 start=0x26FE
  [10] invalid RD link=0 addr=0x3FDE1 rsp=SLVERR ack=1 declared=24576 actual=0 start=0x270E
  [11] invalid WR link=96 addr=0x00060 rsp=SLVERR ack=1 declared=0 actual=0 start=0x4659
  [12] invalid WR link=104 addr=0x1C000 rsp=OK ack=1 declared=0 actual=0 start=0x4703
  [13] invalid WR_NI link=224 addr=0x06D8B rsp=OK ack=0 declared=32004 actual=0 start=0x47FF
  [14] invalid WR_NI link=224 addr=0x06D8B rsp=OK ack=0 declared=32004 actual=0 start=0x4807
  [15] invalid WR link=167 addr=0x060E0 rsp=OK ack=0 declared=224 actual=0 start=0x48FA
  [16] invalid RD_NI link=30 addr=0x070E0 rsp=OK ack=0 declared=24688 actual=0 start=0x4D91
  [17] invalid WR link=16 addr=0x0D7FE rsp=RSP3 ack=1 declared=0 actual=0 start=0x4DED
  [18] invalid WR link=16 addr=0x0D7FE rsp=RSP3 ack=1 declared=0 actual=0 start=0x4DF5
  [19] invalid RD link=88 addr=0x2A000 rsp=OK ack=0 declared=64739 actual=0 start=0x4E6A
  [20] invalid RD link=88 addr=0x2A000 rsp=OK ack=0 declared=64739 actual=0 start=0x4E71
  [21] invalid RD link=0 addr=0x20140 rsp=OK ack=0 declared=16608 actual=0 start=0x52D0
  [22] invalid RD_NI link=167 addr=0x16E10 rsp=OK ack=1 declared=56928 actual=0 start=0x5317
  [23] invalid RD_NI link=31 addr=0x16000 rsp=OK ack=0 declared=61568 actual=0 start=0x536D
  [24] invalid RD_NI link=243 addr=0x118F7 rsp=SLVERR ack=0 declared=57373 actual=0 start=0x564F
  [25] invalid RD link=96 addr=0x0081C rsp=OK ack=0 declared=40559 actual=0 start=0x5652
  [26] invalid RD link=0 addr=0x2E0F4 rsp=OK ack=0 declared=64256 actual=0 start=0x56D4
  [27] invalid RD link=0 addr=0x2E0F4 rsp=OK ack=0 declared=28 actual=0 start=0x56DC
  [28] invalid WR link=25 addr=0x0E09C rsp=OK ack=0 declared=1724 actual=0 start=0x57CD
  [29] invalid WR_NI link=6 addr=0x0B9BB rsp=OK ack=0 declared=31936 actual=0 start=0x57CF
  [30] invalid RD link=128 addr=0x18000 rsp=RSP3 ack=0 declared=7168 actual=0 start=0x57D4
  [31] invalid WR_NI link=6 addr=0x0B9BB rsp=OK ack=0 declared=60768 actual=0 start=0x57D7
  [32] invalid RD_NI link=224 addr=0x0E013 rsp=OK ack=0 declared=43488 actual=0 start=0x585A
  [33] invalid WR link=246 addr=0x00005 rsp=OK ack=0 declared=159 actual=0 start=0x58D5
  [34] invalid RD_NI link=139 addr=0x11F07 rsp=OK ack=0 declared=225 actual=0 start=0x5BD0
  [35] invalid RD_NI link=0 addr=0x0C980 rsp=OK ack=0 declared=59488 actual=0 start=0x5BF5
  [36] invalid RD link=122 addr=0x07ABD rsp=DECERR ack=1 declared=7168 actual=0 start=0x60F4
  [37] invalid RD link=122 addr=0x11C00 rsp=OK ack=1 declared=7261 actual=0 start=0x60F5
  [38] invalid RD_NI link=231 addr=0x100C0 rsp=RSP3 ack=0 declared=64480 actual=0 start=0x6208
  [39] invalid WR link=231 addr=0x3890D rsp=SLVERR ack=1 declared=0 actual=0 start=0x620E
  [40] invalid WR link=231 addr=0x3890D rsp=SLVERR ack=1 declared=0 actual=0 start=0x6216
  [41] invalid RD_NI link=244 addr=0x0A321 rsp=OK ack=0 declared=40962 actual=0 start=0x645C
  [42] invalid RD link=224 addr=0x2A080 rsp=OK ack=0 declared=57568 actual=0 start=0x64C8
  [43] invalid RD link=224 addr=0x2A080 rsp=OK ack=0 declared=57568 actual=0 start=0x64D0
  [44] invalid RD_NI link=137 addr=0x3E0EF rsp=RSP3 ack=1 declared=24803 actual=0 start=0x6AA1
  [45] invalid WR link=234 addr=0x017E3 rsp=OK ack=0 declared=62489 actual=0 start=0x6AA9
warn: scan ended with an incomplete candidate packet
err: timed out waiting for matching secondary reply

verbose rc=4: /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/system_20260427_testplanphase5/bin/sc_tool 2 write 0x08004 0x00000009
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
  wmem[3] = 0x00000009
  wmem[4] = 0x0000009C
  timing main ready   : 59 us
  timing matched      : 0 us
  timing total        : 1022982 us
  secondary before    : 0x9BD6
  secondary after     : 0xEA89
  secondary delta     : 20147 word(s)
  SC main status      : 0x00000001
  SC state            : 0x20000001
warn: skipped non-preamble words while scanning secondary ring
  skipped ring[0x9BD6] = 0x00000000
  skipped ring[0x9BD7] = 0x00000000
  skipped ring[0x9BD8] = 0x00000000
  skipped ring[0x9BD9] = 0x00000000
  skipped ring[0x9BDA] = 0x00000000
  skipped ring[0x9BDB] = 0x00000000
  skipped ring[0x9BDC] = 0x00000000
  skipped ring[0x9BDD] = 0x00000000
info: packets observed on secondary ring:
  [0] invalid RD_NI link=56 addr=0x360E0 rsp=RSP3 ack=0 declared=18 actual=0 start=0xA407
  [1] invalid WR link=104 addr=0x11474 rsp=SLVERR ack=1 declared=0 actual=0 start=0xAE37
  [2] invalid WR link=128 addr=0x00200 rsp=OK ack=1 declared=0 actual=0 start=0xAF69
  [3] invalid RD_NI link=7 addr=0x0F0E0 rsp=SLVERR ack=1 declared=62176 actual=0 start=0xAF74
  [4] invalid WR link=11 addr=0x140F8 rsp=OK ack=0 declared=1888 actual=0 start=0xB028
  [5] invalid WR link=128 addr=0x30020 rsp=SLVERR ack=0 declared=134 actual=0 start=0xB08E
  [6] invalid RD_NI link=160 addr=0x0786F rsp=OK ack=0 declared=32996 actual=0 start=0xB0ED
  [7] invalid WR link=0 addr=0x3C0E1 rsp=RSP3 ack=0 declared=7976 actual=0 start=0xB10C
  [8] invalid WR link=239 addr=0x000E7 rsp=OK ack=0 declared=12544 actual=0 start=0xB178
  [9] invalid RD_NI link=155 addr=0x2570D rsp=RSP3 ack=1 declared=43488 actual=0 start=0xB1C9
  [10] invalid RD_NI link=96 addr=0x1E8E0 rsp=RSP3 ack=0 declared=58735 actual=0 start=0xB23E
  [11] invalid RD_NI link=96 addr=0x1E8E0 rsp=RSP3 ack=0 declared=58735 actual=0 start=0xB246
  [12] invalid RD link=12 addr=0x01D0F rsp=DECERR ack=1 declared=40960 actual=0 start=0xB254
  [13] invalid RD_NI link=18 addr=0x3E7A0 rsp=OK ack=0 declared=41 actual=0 start=0xB283
  [14] invalid WR_NI link=64 addr=0x00067 rsp=SLVERR ack=1 declared=0 actual=0 start=0xB2DA
  [15] invalid WR_NI link=15 addr=0x000E6 rsp=RSP3 ack=0 declared=49183 actual=0 start=0xB34A
  [16] invalid WR_NI link=0 addr=0x0FC94 rsp=DECERR ack=0 declared=32799 actual=0 start=0xB626
  [17] invalid RD link=22 addr=0x0E000 rsp=OK ack=0 declared=40606 actual=0 start=0xB64C
  [18] invalid RD link=22 addr=0x0E000 rsp=OK ack=0 declared=40606 actual=0 start=0xB654
  [19] invalid WR link=240 addr=0x3C080 rsp=OK ack=0 declared=24800 actual=0 start=0xBA75
  [20] invalid RD link=24 addr=0x000DB rsp=DECERR ack=0 declared=219 actual=0 start=0xBDD1
  [21] invalid RD_NI link=160 addr=0x07C07 rsp=DECERR ack=1 declared=58494 actual=0 start=0xC5CD
  [22] invalid RD_NI link=156 addr=0x0F1E0 rsp=SLVERR ack=1 declared=4448 actual=0 start=0xC5F4
  [23] invalid WR_NI link=224 addr=0x3007B rsp=OK ack=0 declared=40160 actual=0 start=0xC659
  [24] invalid WR_NI link=224 addr=0x3007B rsp=OK ack=0 declared=40160 actual=0 start=0xC661
  [25] invalid WR_NI link=252 addr=0x0FF80 rsp=OK ack=0 declared=37399 actual=0 start=0xC66F
  [26] invalid RD_NI link=20 addr=0x36040 rsp=OK ack=0 declared=32608 actual=0 start=0xC6EC
  [27] invalid RD_NI link=20 addr=0x36040 rsp=OK ack=0 declared=32608 actual=0 start=0xC6F4
  [28] invalid RD link=0 addr=0x030E7 rsp=OK ack=0 declared=7040 actual=0 start=0xC700
  [29] invalid RD link=243 addr=0x0F938 rsp=OK ack=0 declared=63713 actual=0 start=0xC78D
  [30] invalid RD link=243 addr=0x0F938 rsp=OK ack=0 declared=17121 actual=0 start=0xC795
  [31] invalid RD_NI link=239 addr=0x140E7 rsp=SLVERR ack=1 declared=63501 actual=0 start=0xCAC4
  [32] invalid RD_NI link=239 addr=0x140E7 rsp=SLVERR ack=1 declared=63501 actual=0 start=0xCACC
  [33] invalid WR_NI link=0 addr=0x2EE0A rsp=OK ack=0 declared=883 actual=0 start=0xCADA
  [34] invalid WR link=29 addr=0x0B600 rsp=OK ack=0 declared=231 actual=0 start=0xCB11
  [35] invalid WR link=125 addr=0x1E097 rsp=OK ack=0 declared=64489 actual=0 start=0xCB18
  [36] invalid WR_NI link=3 addr=0x0041F rsp=OK ack=0 declared=0 actual=0 start=0xCBE0
  [37] invalid RD_NI link=97 addr=0x02080 rsp=SLVERR ack=1 declared=58688 actual=0 start=0xCCA0
  [38] invalid RD_NI link=224 addr=0x3E2F3 rsp=OK ack=0 declared=6368 actual=0 start=0xD7CF
  [39] invalid RD_NI link=224 addr=0x1988C rsp=RSP3 ack=1 declared=1802 actual=0 start=0xD7E0
  [40] invalid RD_NI link=224 addr=0x1988C rsp=RSP3 ack=1 declared=1802 actual=0 start=0xD7E8
  [41] invalid RD link=128 addr=0x02460 rsp=SLVERR ack=1 declared=57354 actual=0 start=0xD7EE
  [42] invalid WR_NI link=120 addr=0x10400 rsp=OK ack=1 declared=0 actual=0 start=0xD876
  [43] invalid WR_NI link=96 addr=0x3E069 rsp=OK ack=0 declared=2016 actual=0 start=0xD97C
  [44] invalid WR_NI link=160 addr=0x28080 rsp=OK ack=0 declared=216 actual=0 start=0xD998
  [45] invalid WR_NI link=24 addr=0x37E33 rsp=OK ack=0 declared=34712 actual=0 start=0xD9D3
  [46] invalid WR_NI link=24 addr=0x37E33 rsp=OK ack=0 declared=34712 actual=0 start=0xD9DB
  [47] invalid RD link=235 addr=0x093E0 rsp=OK ack=0 declared=41952 actual=0 start=0xD9E6
  [48] invalid RD link=3 addr=0x000EF rsp=SLVERR ack=0 declared=7191 actual=0 start=0xDAD9
  [49] invalid RD link=3 addr=0x000EF rsp=RSP3 ack=0 declared=32946 actual=0 start=0xDAE1
  [50] invalid RD_NI link=96 addr=0x300E0 rsp=OK ack=1 declared=224 actual=0 start=0xDDC6
  [51] invalid WR_NI link=64 addr=0x0E060 rsp=OK ack=0 declared=57568 actual=0 start=0xDDDB
  [52] invalid WR_NI link=64 addr=0x0E060 rsp=OK ack=0 declared=57568 actual=0 start=0xDDE3
  [53] invalid WR link=160 addr=0x160A0 rsp=OK ack=0 declared=60782 actual=0 start=0xDE0C
  [54] invalid WR link=0 addr=0x2E06F rsp=SLVERR ack=0 declared=57568 actual=0 start=0xDE2C
  [55] invalid RD link=0 addr=0x0E000 rsp=OK ack=1 declared=57575 actual=0 start=0xDE49
  [56] invalid RD link=0 addr=0x0E000 rsp=OK ack=1 declared=57575 actual=0 start=0xDE51
  [57] invalid RD link=204 addr=0x06080 rsp=OK ack=0 declared=60672 actual=0 start=0xDF12
  [58] invalid RD link=96 addr=0x30080 rsp=DECERR ack=1 declared=57499 actual=0 start=0xDF2C
  [59] invalid RD link=0 addr=0x000BF rsp=OK ack=0 declared=1808 actual=0 start=0xDF81
  [60] invalid RD_NI link=96 addr=0x01307 rsp=RSP3 ack=1 declared=24 actual=0 start=0xDFD1
  [61] invalid RD_NI link=0 addr=0x11E00 rsp=OK ack=0 declared=7174 actual=0 start=0xE03D
  [62] invalid RD_NI link=0 addr=0x11E00 rsp=OK ack=0 declared=7174 actual=0 start=0xE045
  [63] invalid RD_NI link=64 addr=0x3E828 rsp=OK ack=1 declared=37883 actual=0 start=0xE06D
  [64] invalid RD_NI link=96 addr=0x01D00 rsp=OK ack=0 declared=24864 actual=0 start=0xE09B
  [65] invalid RD_NI link=96 addr=0x01D00 rsp=RSP3 ack=1 declared=34456 actual=0 start=0xE0A3
  [66] invalid RD link=1 addr=0x36000 rsp=RSP3 ack=0 declared=6941 actual=0 start=0xE6DF
  [67] invalid RD_NI link=64 addr=0x240F0 rsp=OK ack=0 declared=52704 actual=0 start=0xE7D7
  [68] invalid RD link=96 addr=0x1E7FB rsp=OK ack=0 declared=480 actual=0 start=0xE8DB
  [69] invalid WR_NI link=198 addr=0x000C9 rsp=OK ack=0 declared=57395 actual=0 start=0xE947
  [70] invalid WR_NI link=198 addr=0x000C9 rsp=OK ack=0 declared=6144 actual=0 start=0xE94F
  [71] invalid WR link=71 addr=0x020F9 rsp=OK ack=0 declared=57566 actual=0 start=0xE959
  [72] invalid RD_NI link=103 addr=0x00D60 rsp=SLVERR ack=1 declared=61760 actual=0 start=0xE9AB
  [73] invalid RD_NI link=103 addr=0x00D60 rsp=SLVERR ack=1 declared=61760 actual=0 start=0xE9B2
  [74] invalid RD link=57 addr=0x38011 rsp=RSP3 ack=1 declared=1888 actual=0 start=0xEA24
  [75] invalid RD link=57 addr=0x28011 rsp=RSP3 ack=0 declared=62464 actual=0 start=0xEA2C
  [76] invalid RD link=224 addr=0x0609C rsp=RSP3 ack=1 declared=188 actual=0 start=0xEA34
  [77] invalid WR link=0 addr=0x0FEE0 rsp=OK ack=0 declared=58112 actual=0 start=0xEA36
warn: scan ended with an incomplete candidate packet
err: timed out waiting for matching secondary reply
`

