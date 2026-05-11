# Phase 5 Injector Datapath Sanity Report

- Timestamp: `2026-04-30T10:23:10`
- SC link: `2`
- Device: `/dev/mudaq0`
- FEB target: `7`
- Source: `real`
- Source emulator mask: `0x0000009F`
- LVDS lane-go mask: `0x00000060`
- LVDS configured by runner: `yes`
- LVDS SVD snapshot: `yes`
- LVDS per-lane DPA unlock reads: `yes`
- Histogram bin dump: `yes`
- Active emulator lanes: `0x00000000`
- Inject mode: `periodic`
- Injector layout: `legacy_direct`
- Injector base/control offset: `0x0000AC80` / `0` words
- Histogram profile: `delay-mts-both`
- Rate tolerance: `1.000%`
- Real hits per lane for rate expectation: `32`
- Histogram filter enable: `False`
- Histogram filter key loc override: `None`
- Histogram filter key value: `0x00000000`
- MTS expected latency override: `2000`
- MTS bypass-lapse override: `keep`
- MTS delay-ts field override: `t`
- MTS drop-delay-error override: `off`
- Ring filter-inerr override: `on`
- Result: `FAIL`

## Case Summary

| Case | Run | Source | Mode | Interval | Hist Hits | Hist Drops | MTS Hits | Ring InErr | Real Beats | LVDS Err Δ | DPA Unlock Δ | Class |
|---:|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | 45000 | `real` | `periodic` | 1250 | 0 | 0 | 0 | 0 | 0 | n/a | n/a | `exception` |

## Configuration Notes

- The active `mutrig_injector_0` exposes one `coe_inject_pulse` output. The emulator `inject_channel_mask` CSR is still written for visibility, but that mask only affects the separate masked-trigger conduit and is not driven by this injector instance.
- Channel sanity in this report is therefore represented by emulator cluster center/size; ASIC sanity is represented by `active_lanes_mask` and the per-lane source mux selection.
- Scoped real-source runs select disabled emulator sources on non-requested lanes; otherwise an aligned idle/live MuTRiG lane can continue into MTS/histogram even when the LVDS lane-go mask requests a single lane.
- The runner writes injector mode `0` before setup and immediately after the injection window because the current injector RTL accepts run-control but does not gate the pulse arbiter by RUNNING.
- The runner autodetects the injector CSR layout. Current programmed images without UID/META use MODE at base+0; packaged images with UID/META use MODE at base+2.

## Per-Case Details

### Case 0

- Run number: `45000`
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
- Histogram rate counter source: `live_delta`
- Histogram live delta: `0` / dropped `0`
- Histogram last interval: `0` / dropped `0`
- Rate expected/tolerance/error: `0` / `±0` / `0` hits
- Post-end clean: `no`
- LVDS error delta lanes: `n/a`
- LVDS DPA unlock delta lanes: `n/a`

- Error: `SC transaction failed after quiet/verbose attempts
quiet rc=4: firmware_builds/systems/system_20260427_testplanphase5/bin/sc_tool 2 read 0x0A830 16 --quiet
info: request summary:
  type               : RD
  link               : 2
  addr               : 0x0A830
  request length     : 16 word(s)
  main length reg    : 2
  expected reply words (actual)   : 20
  expected reply words (declared) : 20
info: request words written to SC main:
  wmem[0] = 0x1C0002BC
  wmem[1] = 0x0000A830
  wmem[2] = 0x00000010
  wmem[3] = 0x0000009C
  timing main ready   : 58 us
  timing matched      : 0 us
  timing total        : 1019239 us
  secondary before    : 0x0070
  secondary after     : 0x6D70
  secondary delta     : 27904 word(s)
  SC main status      : 0x00000001
  SC state            : 0x40000001
warn: skipped non-preamble words while scanning secondary ring
  skipped ring[0x0070] = 0x00000000
  skipped ring[0x0071] = 0x00000000
  skipped ring[0x0072] = 0x00000000
  skipped ring[0x0073] = 0x00000000
  skipped ring[0x0074] = 0x00000000
  skipped ring[0x0075] = 0x00000000
  skipped ring[0x0076] = 0x00000000
  skipped ring[0x0077] = 0x00000000
info: packets observed on secondary ring:
  [0] invalid WR_NI link=248 addr=0x000E0 rsp=SLVERR ack=1 declared=0 actual=0 start=0x0E0D
  [1] invalid WR_NI link=164 addr=0x0A009 rsp=SLVERR ack=1 declared=0 actual=0 start=0x0E33
  [2] invalid WR_NI link=164 addr=0x0A009 rsp=SLVERR ack=1 declared=0 actual=0 start=0x0E3B
  [3] invalid WR link=128 addr=0x2E04E rsp=RSP3 ack=1 declared=0 actual=0 start=0x0E60
  [4] invalid WR_NI link=128 addr=0x1E400 rsp=RSP3 ack=0 declared=135 actual=0 start=0x0F13
  [5] invalid RD link=30 addr=0x1406F rsp=OK ack=0 declared=49280 actual=0 start=0x115F
  [6] invalid RD link=128 addr=0x00700 rsp=RSP3 ack=0 declared=49152 actual=0 start=0x11CA
  [7] invalid RD_NI link=225 addr=0x3FE9C rsp=DECERR ack=0 declared=16392 actual=0 start=0x1568
  [8] invalid RD_NI link=0 addr=0x01800 rsp=OK ack=0 declared=8384 actual=0 start=0x1579
  [9] invalid RD_NI link=152 addr=0x3E700 rsp=OK ack=0 declared=31968 actual=0 start=0x15E2
  [10] invalid RD_NI link=0 addr=0x08007 rsp=OK ack=0 declared=22142 actual=0 start=0x164A
  [11] invalid WR_NI link=64 addr=0x07428 rsp=OK ack=0 declared=32768 actual=0 start=0x1666
  [12] invalid WR_NI link=63 addr=0x361E0 rsp=DECERR ack=1 declared=0 actual=0 start=0x1672
  [13] invalid WR_NI link=120 addr=0x0FD00 rsp=OK ack=0 declared=64636 actual=0 start=0x167F
  [14] invalid WR link=105 addr=0x000BC rsp=OK ack=1 declared=0 actual=0 start=0x170E
  [15] invalid RD link=4 addr=0x0E0FC rsp=DECERR ack=0 declared=57344 actual=0 start=0x17D8
  [16] invalid RD_NI link=125 addr=0x26400 rsp=DECERR ack=1 declared=64448 actual=0 start=0x1A12
  [17] invalid RD link=82 addr=0x1E078 rsp=DECERR ack=0 declared=57568 actual=0 start=0x1A75
  [18] invalid RD link=197 addr=0x200E0 rsp=DECERR ack=0 declared=3201 actual=0 start=0x1A94
  [19] invalid RD link=254 addr=0x018BE rsp=RSP3 ack=0 declared=32352 actual=0 start=0x1BF1
  [20] invalid WR_NI link=0 addr=0x3608F rsp=SLVERR ack=1 declared=0 actual=0 start=0x2328
  [21] invalid RD link=128 addr=0x3EF60 rsp=OK ack=1 declared=8210 actual=0 start=0x25F6
  [22] invalid WR_NI link=32 addr=0x30000 rsp=OK ack=0 declared=32 actual=0 start=0x27F2
  [23] invalid RD_NI link=29 addr=0x0F1E0 rsp=OK ack=0 declared=6016 actual=0 start=0x287A
  [24] invalid WR_NI link=96 addr=0x0BD40 rsp=OK ack=1 declared=0 actual=0 start=0x2980
  [25] invalid WR link=32 addr=0x0FCE0 rsp=RSP3 ack=1 declared=0 actual=0 start=0x29B1
  [26] invalid WR_NI link=0 addr=0x00080 rsp=SLVERR ack=1 declared=0 actual=0 start=0x2DEA
  [27] invalid RD link=190 addr=0x3EC0F rsp=RSP3 ack=0 declared=57568 actual=0 start=0x2E41
  [28] invalid WR_NI link=128 addr=0x2F8E0 rsp=RSP3 ack=0 declared=29 actual=0 start=0x2F47
  [29] invalid WR_NI link=128 addr=0x2F8E0 rsp=RSP3 ack=0 declared=29 actual=0 start=0x2F4E
  [30] invalid WR_NI link=224 addr=0x0C09D rsp=OK ack=0 declared=8423 actual=0 start=0x2F70
  [31] invalid RD link=3 addr=0x100E1 rsp=SLVERR ack=1 declared=16 actual=0 start=0x2FA3
  [32] invalid RD link=142 addr=0x080DD rsp=DECERR ack=0 declared=64507 actual=0 start=0x3243
  [33] invalid RD link=136 addr=0x11CE4 rsp=OK ack=0 declared=24067 actual=0 start=0x3387
  [34] invalid RD link=136 addr=0x11CE4 rsp=OK ack=0 declared=24067 actual=0 start=0x338F
  [35] invalid WR_NI link=192 addr=0x380F6 rsp=SLVERR ack=1 declared=0 actual=0 start=0x3549
  [36] invalid WR link=27 addr=0x3E004 rsp=DECERR ack=0 declared=25280 actual=0 start=0x35E5
  [37] invalid WR link=27 addr=0x3E004 rsp=DECERR ack=0 declared=25280 actual=0 start=0x35ED
  [38] invalid RD link=0 addr=0x00030 rsp=DECERR ack=0 declared=97 actual=0 start=0x3698
  [39] invalid RD link=0 addr=0x00030 rsp=DECERR ack=0 declared=97 actual=0 start=0x36A0
  [40] invalid WR_NI link=0 addr=0x0E0FC rsp=OK ack=0 declared=35031 actual=0 start=0x36E0
  [41] invalid WR link=128 addr=0x1A700 rsp=SLVERR ack=0 declared=36 actual=0 start=0x3DBF
  [42] invalid WR link=0 addr=0x29C20 rsp=SLVERR ack=0 declared=3584 actual=0 start=0x3E02
  [43] invalid WR link=22 addr=0x3E617 rsp=OK ack=0 declared=57344 actual=0 start=0x3E17
  [44] invalid RD link=0 addr=0x3870C rsp=OK ack=0 declared=59360 actual=0 start=0x4073
  [45] invalid RD link=0 addr=0x2EF76 rsp=OK ack=0 declared=61850 actual=0 start=0x40D7
  [46] invalid WR_NI link=0 addr=0x00BE7 rsp=RSP3 ack=0 declared=35007 actual=0 start=0x4119
  [47] invalid WR_NI link=0 addr=0x00BE7 rsp=RSP3 ack=0 declared=8416 actual=0 start=0x411F
  [48] invalid WR link=224 addr=0x000F2 rsp=DECERR ack=0 declared=57383 actual=0 start=0x4AA1
  [49] invalid RD link=237 addr=0x3680F rsp=RSP3 ack=0 declared=32992 actual=0 start=0x4BA4
  [50] invalid WR_NI link=232 addr=0x02416 rsp=OK ack=0 declared=36071 actual=0 start=0x515E
  [51] invalid RD_NI link=21 addr=0x04000 rsp=OK ack=0 declared=224 actual=0 start=0x51A0
  [52] invalid RD_NI link=218 addr=0x00EC8 rsp=OK ack=0 declared=63501 actual=0 start=0x6C13
  [53] invalid RD_NI link=160 addr=0x38003 rsp=SLVERR ack=1 declared=14 actual=0 start=0x6CD7
  [54] invalid RD_NI link=227 addr=0x00160 rsp=OK ack=0 declared=36736 actual=0 start=0x6CEC
warn: scan ended with an incomplete candidate packet
err: timed out waiting for matching secondary reply

verbose rc=4: firmware_builds/systems/system_20260427_testplanphase5/bin/sc_tool 2 read 0x0A830 16
board:
  PLL_LOCKED_REGISTER_R      = 0x00000000
  LINK_LOCKED_LOW_REGISTER_R = 0x13000000
  LINK_LOCKED_HIGH_REGISTER_R= 0x00000F00
  RESET_LINK_STATUS_REGISTER_R = 0x00000000
info: request summary:
  type               : RD
  link               : 2
  addr               : 0x0A830
  request length     : 16 word(s)
  main length reg    : 2
  expected reply words (actual)   : 20
  expected reply words (declared) : 20
info: request words written to SC main:
  wmem[0] = 0x1C0002BC
  wmem[1] = 0x0000A830
  wmem[2] = 0x00000010
  wmem[3] = 0x0000009C
  timing main ready   : 59 us
  timing matched      : 0 us
  timing total        : 1015697 us
  secondary before    : 0x2669
  secondary after     : 0x9026
  secondary delta     : 27069 word(s)
  SC main status      : 0x00000001
  SC state            : 0x40000001
warn: skipped non-preamble words while scanning secondary ring
  skipped ring[0x2669] = 0x00000000
  skipped ring[0x266A] = 0x00000000
  skipped ring[0x266B] = 0x00000000
  skipped ring[0x266C] = 0x00000000
  skipped ring[0x266D] = 0x00000000
  skipped ring[0x266E] = 0x00000000
  skipped ring[0x266F] = 0x00000000
  skipped ring[0x2670] = 0x00000000
info: packets observed on secondary ring:
  [0] invalid RD link=131 addr=0x3F204 rsp=OK ack=0 declared=224 actual=0 start=0x3C46
  [1] invalid WR link=31 addr=0x09300 rsp=OK ack=0 declared=33000 actual=0 start=0x414C
  [2] invalid RD link=96 addr=0x1679C rsp=RSP3 ack=1 declared=24764 actual=0 start=0x423A
  [3] invalid RD link=96 addr=0x01C7C rsp=OK ack=0 declared=16416 actual=0 start=0x423C
  [4] invalid RD link=77 addr=0x31320 rsp=OK ack=0 declared=0 actual=0 start=0x4280
  [5] invalid RD_NI link=0 addr=0x07C16 rsp=OK ack=0 declared=36319 actual=0 start=0x476D
  [6] invalid WR_NI link=0 addr=0x0E000 rsp=SLVERR ack=0 declared=49159 actual=0 start=0x477A
  [7] invalid WR link=253 addr=0x398D1 rsp=RSP3 ack=1 declared=0 actual=0 start=0x479B
  [8] invalid RD_NI link=242 addr=0x34E70 rsp=OK ack=1 declared=32768 actual=0 start=0x47BE
  [9] invalid RD_NI link=32 addr=0x3FB57 rsp=OK ack=0 declared=57371 actual=0 start=0x492A
  [10] invalid RD_NI link=46 addr=0x01C60 rsp=OK ack=0 declared=33006 actual=0 start=0x494E
  [11] invalid RD link=96 addr=0x3610F rsp=RSP3 ack=1 declared=2958 actual=0 start=0x49BC
  [12] invalid RD link=232 addr=0x1F980 rsp=SLVERR ack=1 declared=186 actual=0 start=0x49FC
  [13] invalid RD link=232 addr=0x1F980 rsp=SLVERR ack=1 declared=186 actual=0 start=0x4A04
  [14] invalid RD link=121 addr=0x1E8E0 rsp=OK ack=0 declared=24768 actual=0 start=0x4A54
  [15] invalid RD link=121 addr=0x1E8E0 rsp=OK ack=0 declared=2240 actual=0 start=0x4A5C
  [16] invalid RD link=167 addr=0x00080 rsp=DECERR ack=1 declared=12984 actual=0 start=0x4A9B
  [17] invalid RD link=0 addr=0x0601B rsp=OK ack=0 declared=0 actual=0 start=0x4BF1
  [18] invalid WR link=8 addr=0x3601F rsp=DECERR ack=1 declared=0 actual=0 start=0x4D96
  [19] invalid RD_NI link=226 addr=0x08113 rsp=SLVERR ack=0 declared=36928 actual=0 start=0x4E39
  [20] invalid WR_NI link=125 addr=0x0FAE0 rsp=SLVERR ack=0 declared=60959 actual=0 start=0x517C
  [21] invalid RD_NI link=0 addr=0x119E0 rsp=OK ack=0 declared=57408 actual=0 start=0x51F8
  [22] invalid RD_NI link=0 addr=0x119E0 rsp=OK ack=0 declared=57408 actual=0 start=0x5200
  [23] invalid RD_NI link=32 addr=0x02C20 rsp=OK ack=0 declared=63456 actual=0 start=0x5282
  [24] invalid RD_NI link=32 addr=0x02C20 rsp=OK ack=0 declared=63456 actual=0 start=0x528A
  [25] invalid RD_NI link=81 addr=0x02A00 rsp=DECERR ack=1 declared=20463 actual=0 start=0x55E4
  [26] invalid RD link=224 addr=0x300E0 rsp=SLVERR ack=0 declared=64776 actual=0 start=0x5978
  [27] invalid RD_NI link=140 addr=0x39B36 rsp=OK ack=0 declared=13536 actual=0 start=0x59BD
  [28] invalid WR_NI link=224 addr=0x300E0 rsp=SLVERR ack=0 declared=32382 actual=0 start=0x5AC3
  [29] invalid RD_NI link=0 addr=0x32086 rsp=OK ack=0 declared=186 actual=0 start=0x5AE4
  [30] invalid RD link=224 addr=0x00F00 rsp=OK ack=0 declared=57368 actual=0 start=0x5B48
  [31] invalid RD_NI link=248 addr=0x1E778 rsp=DECERR ack=0 declared=103 actual=0 start=0x5C2C
  [32] invalid WR link=145 addr=0x34017 rsp=DECERR ack=1 declared=0 actual=0 start=0x5C59
  [33] invalid WR link=0 addr=0x260EE rsp=OK ack=0 declared=30944 actual=0 start=0x5D5F
  [34] invalid RD_NI link=224 addr=0x2628B rsp=OK ack=0 declared=25327 actual=0 start=0x5D7E
  [35] invalid RD_NI link=224 addr=0x2628B rsp=OK ack=0 declared=25327 actual=0 start=0x5D85
  [36] invalid RD_NI link=158 addr=0x20408 rsp=RSP3 ack=1 declared=36611 actual=0 start=0x5D95
  [37] invalid RD_NI link=158 addr=0x20408 rsp=RSP3 ack=1 declared=36611 actual=0 start=0x5D9D
  [38] invalid WR link=0 addr=0x06040 rsp=OK ack=0 declared=28258 actual=0 start=0x67AC
  [39] invalid WR link=0 addr=0x06040 rsp=OK ack=0 declared=28258 actual=0 start=0x67B4
  [40] invalid WR_NI link=104 addr=0x08871 rsp=SLVERR ack=1 declared=0 actual=0 start=0x67CE
  [41] invalid RD_NI link=7 addr=0x000F1 rsp=SLVERR ack=1 declared=224 actual=0 start=0x6814
  [42] invalid RD link=96 addr=0x300C7 rsp=RSP3 ack=0 declared=0 actual=0 start=0x6860
  [43] invalid RD link=7 addr=0x0049B rsp=OK ack=0 declared=64 actual=0 start=0x68B1
  [44] invalid WR link=224 addr=0x3E7B0 rsp=OK ack=0 declared=57510 actual=0 start=0x6932
  [45] invalid RD link=5 addr=0x33E10 rsp=OK ack=0 declared=59408 actual=0 start=0x6C25
  [46] invalid RD link=5 addr=0x33E10 rsp=OK ack=0 declared=59408 actual=0 start=0x6C2D
  [47] invalid WR link=167 addr=0x0931D rsp=OK ack=0 declared=21560 actual=0 start=0x6CCD
  [48] invalid RD link=224 addr=0x30080 rsp=SLVERR ack=1 declared=29436 actual=0 start=0x6DE3
  [49] invalid RD link=224 addr=0x30080 rsp=OK ack=0 declared=63740 actual=0 start=0x6DEB
  [50] invalid WR link=16 addr=0x0BC07 rsp=DECERR ack=1 declared=0 actual=0 start=0x6E3B
  [51] invalid WR link=16 addr=0x0BC07 rsp=DECERR ack=1 declared=0 actual=0 start=0x6E43
  [52] invalid RD link=0 addr=0x0004F rsp=RSP3 ack=1 declared=18428 actual=0 start=0x6E65
  [53] invalid RD_NI link=254 addr=0x06000 rsp=OK ack=0 declared=57487 actual=0 start=0x6E81
  [54] invalid RD_NI link=254 addr=0x06000 rsp=OK ack=0 declared=57487 actual=0 start=0x6E88
  [55] invalid WR link=152 addr=0x008E0 rsp=OK ack=0 declared=37081 actual=0 start=0x6EE1
  [56] invalid WR link=156 addr=0x17CE0 rsp=DECERR ack=1 declared=0 actual=0 start=0x6FD0
  [57] invalid RD_NI link=64 addr=0x1EFED rsp=OK ack=0 declared=26848 actual=0 start=0x712B
  [58] invalid WR_NI link=224 addr=0x2E000 rsp=SLVERR ack=1 declared=0 actual=0 start=0x7189
  [59] invalid RD_NI link=0 addr=0x1FD67 rsp=OK ack=0 declared=49344 actual=0 start=0x71B8
  [60] invalid RD_NI link=0 addr=0x1FD67 rsp=OK ack=0 declared=49344 actual=0 start=0x71C0
  [61] invalid RD link=192 addr=0x13007 rsp=OK ack=0 declared=30744 actual=0 start=0x71F3
  [62] invalid RD link=192 addr=0x13007 rsp=OK ack=0 declared=30744 actual=0 start=0x71FA
  [63] invalid RD_NI link=96 addr=0x08045 rsp=RSP3 ack=1 declared=7954 actual=0 start=0x73BB
  [64] invalid RD_NI link=96 addr=0x08045 rsp=RSP3 ack=1 declared=7954 actual=0 start=0x73C3
  [65] invalid RD link=30 addr=0x0B800 rsp=OK ack=0 declared=8 actual=0 start=0x76B9
  [66] invalid RD_NI link=148 addr=0x196E0 rsp=RSP3 ack=1 declared=34675 actual=0 start=0x7A84
  [67] invalid WR_NI link=0 addr=0x215F7 rsp=OK ack=0 declared=57358 actual=0 start=0x7A99
  [68] invalid WR link=239 addr=0x26746 rsp=DECERR ack=1 declared=0 actual=0 start=0x7AAB
  [69] invalid RD link=248 addr=0x0DCE2 rsp=OK ack=0 declared=29440 actual=0 start=0x7B17
  [70] invalid RD link=0 addr=0x00C65 rsp=OK ack=0 declared=376 actual=0 start=0x7BA5
  [71] invalid RD link=0 addr=0x00C65 rsp=OK ack=0 declared=376 actual=0 start=0x7BAC
  [72] invalid RD_NI link=224 addr=0x3E57D rsp=RSP3 ack=0 declared=61632 actual=0 start=0x7D83
  [73] invalid WR link=135 addr=0x01DC0 rsp=OK ack=0 declared=16627 actual=0 start=0x7DDF
  [74] invalid WR link=135 addr=0x01DC0 rsp=OK ack=0 declared=16627 actual=0 start=0x7DE7
  [75] invalid RD_NI link=0 addr=0x3369C rsp=OK ack=0 declared=59008 actual=0 start=0x7E3E
  [76] invalid RD_NI link=0 addr=0x3369C rsp=RSP3 ack=1 declared=20608 actual=0 start=0x7E46
  [77] invalid WR link=224 addr=0x00000 rsp=RSP3 ack=1 declared=0 actual=0 start=0x7E74
  [78] invalid WR link=250 addr=0x01700 rsp=OK ack=0 declared=57471 actual=0 start=0x7F12
  [79] invalid WR link=250 addr=0x01700 rsp=OK ack=0 declared=0 actual=0 start=0x7F1A
  [80] invalid WR link=126 addr=0x09DE8 rsp=DECERR ack=1 declared=0 actual=0 start=0x856F
  [81] invalid WR link=66 addr=0x0EB80 rsp=OK ack=0 declared=3699 actual=0 start=0x85B5
  [82] invalid RD link=0 addr=0x00B14 rsp=OK ack=0 declared=62976 actual=0 start=0x85C6
  [83] invalid RD_NI link=232 addr=0x0007E rsp=OK ack=0 declared=248 actual=0 start=0x8A1D
  [84] invalid RD_NI link=234 addr=0x02017 rsp=RSP3 ack=0 declared=4081 actual=0 start=0x8A26
  [85] invalid WR_NI link=32 addr=0x0E01E rsp=OK ack=0 declared=61374 actual=0 start=0x8B99
  [86] invalid WR_NI link=32 addr=0x0E01E rsp=RSP3 ack=1 declared=0 actual=0 start=0x8BA1
  [87] invalid WR link=0 addr=0x2F800 rsp=OK ack=0 declared=11392 actual=0 start=0x8BA3
  [88] invalid RD link=127 addr=0x0E086 rsp=DECERR ack=1 declared=62232 actual=0 start=0x8D5B
  [89] invalid RD link=0 addr=0x0C007 rsp=OK ack=0 declared=64480 actual=0 start=0x8D5E
  [90] invalid RD link=224 addr=0x0FEE0 rsp=SLVERR ack=0 declared=61670 actual=0 start=0x8EE3
  [91] invalid WR link=0 addr=0x02F79 rsp=OK ack=0 declared=59376 actual=0 start=0x8EE7
  [92] invalid WR link=0 addr=0x02F79 rsp=OK ack=0 declared=59376 actual=0 start=0x8EEF
  [93] invalid WR link=226 addr=0x00000 rsp=OK ack=0 declared=7063 actual=0 start=0x8F0B
  [94] invalid RD link=0 addr=0x377F6 rsp=OK ack=0 declared=57473 actual=0 start=0x8F59
  [95] invalid WR_NI link=103 addr=0x200FF rsp=OK ack=0 declared=46848 actual=0 start=0x8FB5
  [96] invalid WR_NI link=224 addr=0x11780 rsp=RSP3 ack=1 declared=0 actual=0 start=0x8FBC
warn: scan ended with an incomplete candidate packet
err: timed out waiting for matching secondary reply
`

