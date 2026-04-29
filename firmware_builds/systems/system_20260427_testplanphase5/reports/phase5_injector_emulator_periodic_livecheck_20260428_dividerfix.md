# Phase 5 Injector Datapath Sanity Report

- Timestamp: `2026-04-28T20:06:38`
- SC link: `2`
- Device: `/dev/mudaq0`
- FEB target: `0`
- Source: `emulator`
- Source emulator mask: `0x000000FF`
- Active emulator lanes: `0x000000FF`
- Inject mode: `periodic`
- Result: `FAIL`

## Case Summary

| Case | Run | Source | Mode | Interval | Hist Hits | Hist Drops | MTS Hits | Ring InErr | Real Beats | Emu Beats | Class |
|---:|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | 45100 | `emulator` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 0 | 0 | `exception` |

## Configuration Notes

- The active `mutrig_injector_0` exposes one `coe_inject_pulse` output. The emulator `inject_channel_mask` CSR is still written for visibility, but that mask only affects the separate masked-trigger conduit and is not driven by this injector instance.
- Channel sanity in this report is therefore represented by emulator cluster center/size; ASIC sanity is represented by `active_lanes_mask` and the per-lane source mux selection.
- The runner writes injector mode `0` before setup and immediately after the injection window because the current injector RTL accepts run-control but does not gate the pulse arbiter by RUNNING.

## Per-Case Details

### Case 0

- Run number: `45100`
- Pulse interval: `12500`
- Pulse high cycles: `?`
- Injector mode during run: `?`
- Injector mode after run: `?`
- Lane-go readback: `0x00000000`
- Histogram ingress status: `0x00000000`
- Source mux selected beat delta: `0`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
- Post-end clean: `no`

- Error: `command failed rc=4: /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/system_20260427_testplanphase5/bin/sc_tool 2 write 0x0AC80 0x00000000 --quiet
info: request summary:
  type               : WR
  link               : 2
  addr               : 0x0AC80
  request length     : 1 word(s)
  main length reg    : 3
  expected reply words (actual)   : 4
  expected reply words (declared) : 4
info: request words written to SC main:
  wmem[0] = 0x1D0002BC
  wmem[1] = 0x0000AC80
  wmem[2] = 0x00000001
  wmem[3] = 0x00000000
  wmem[4] = 0x0000009C
  timing main ready   : 58 us
  timing matched      : 0 us
  timing total        : 1003797 us
  secondary before    : 0x20C5
  secondary after     : 0x5855
  secondary delta     : 14224 word(s)
  SC main status      : 0x00000001
  SC state            : 0x40000001
warn: skipped non-preamble words while scanning secondary ring
  skipped ring[0x20C5] = 0x00000000
  skipped ring[0x20C6] = 0x00000000
  skipped ring[0x20C7] = 0x00000000
  skipped ring[0x20C8] = 0x00000000
  skipped ring[0x20C9] = 0x00000000
  skipped ring[0x20CA] = 0x00000000
  skipped ring[0x20CB] = 0x00000000
  skipped ring[0x20CC] = 0x00000000
info: packets observed on secondary ring:
  [0] invalid RD link=234 addr=0x0000F rsp=OK ack=0 declared=57568 actual=0 start=0x2B89
  [1] invalid WR_NI link=0 addr=0x0E020 rsp=DECERR ack=0 declared=57851 actual=0 start=0x2CD5
  [2] invalid WR link=96 addr=0x0FEC7 rsp=OK ack=0 declared=7394 actual=0 start=0x2D1F
  [3] invalid WR link=96 addr=0x0FEC7 rsp=SLVERR ack=1 declared=0 actual=0 start=0x2D27
  [4] invalid RD link=1 addr=0x0A0E0 rsp=SLVERR ack=0 declared=49159 actual=0 start=0x2D4E
  [5] invalid RD_NI link=192 addr=0x3AF00 rsp=RSP3 ack=1 declared=54528 actual=0 start=0x2D97
  [6] invalid WR_NI link=103 addr=0x00120 rsp=OK ack=0 declared=57468 actual=0 start=0x2DE0
  [7] invalid RD_NI link=160 addr=0x3E080 rsp=SLVERR ack=1 declared=7 actual=0 start=0x372B
  [8] invalid RD_NI link=160 addr=0x27C00 rsp=OK ack=0 declared=59392 actual=0 start=0x3733
  [9] invalid RD_NI link=232 addr=0x005E0 rsp=OK ack=0 declared=64528 actual=0 start=0x375C
  [10] invalid RD_NI link=232 addr=0x2F200 rsp=DECERR ack=0 declared=24615 actual=0 start=0x3764
  [11] invalid WR link=0 addr=0x0B084 rsp=OK ack=0 declared=56848 actual=0 start=0x3A60
  [12] invalid RD link=30 addr=0x3F000 rsp=RSP3 ack=0 declared=30432 actual=0 start=0x3B2E
  [13] invalid RD link=254 addr=0x0C000 rsp=RSP3 ack=0 declared=7428 actual=0 start=0x3DB8
  [14] invalid WR_NI link=0 addr=0x0DD60 rsp=RSP3 ack=1 declared=0 actual=0 start=0x4162
  [15] invalid WR_NI link=0 addr=0x0DD60 rsp=RSP3 ack=1 declared=0 actual=0 start=0x416A
  [16] invalid WR_NI link=224 addr=0x2FDDC rsp=RSP3 ack=1 declared=0 actual=0 start=0x4177
  [17] invalid WR_NI link=242 addr=0x0E000 rsp=OK ack=0 declared=57568 actual=0 start=0x4226
  [18] invalid WR_NI link=96 addr=0x1601E rsp=RSP3 ack=1 declared=0 actual=0 start=0x44DD
  [19] invalid RD link=238 addr=0x2C00C rsp=OK ack=0 declared=59520 actual=0 start=0x479F
  [20] invalid WR link=224 addr=0x01820 rsp=OK ack=0 declared=1499 actual=0 start=0x48CC
  [21] invalid RD link=21 addr=0x0F112 rsp=RSP3 ack=1 declared=32792 actual=0 start=0x4923
  [22] invalid RD_NI link=189 addr=0x3FB60 rsp=OK ack=0 declared=20462 actual=0 start=0x49D2
  [23] invalid WR link=129 addr=0x081BD rsp=OK ack=0 declared=0 actual=0 start=0x4C9E
  [24] invalid WR link=129 addr=0x00000 rsp=OK ack=0 declared=0 actual=0 start=0x4C9F
  [25] invalid WR_NI link=0 addr=0x31900 rsp=DECERR ack=1 declared=0 actual=0 start=0x5064
  [26] invalid RD_NI link=0 addr=0x249E0 rsp=RSP3 ack=0 declared=480 actual=0 start=0x5074
  [27] invalid RD_NI link=0 addr=0x249E0 rsp=RSP3 ack=0 declared=480 actual=0 start=0x507C
  [28] invalid WR link=28 addr=0x3609E rsp=OK ack=0 declared=41088 actual=0 start=0x509A
  [29] invalid RD link=19 addr=0x0607E rsp=SLVERR ack=0 declared=32008 actual=0 start=0x52D5
  [30] invalid RD link=128 addr=0x00040 rsp=RSP3 ack=0 declared=25833 actual=0 start=0x52DC
  [31] invalid RD_NI link=231 addr=0x38FAB rsp=SLVERR ack=1 declared=33616 actual=0 start=0x5307
  [32] invalid RD_NI link=231 addr=0x38FAB rsp=SLVERR ack=1 declared=33616 actual=0 start=0x530F
  [33] invalid RD_NI link=27 addr=0x0EC9C rsp=RSP3 ack=1 declared=59324 actual=0 start=0x53C0
  [34] invalid RD_NI link=231 addr=0x30786 rsp=OK ack=1 declared=25056 actual=0 start=0x53C2
  [35] invalid RD_NI link=231 addr=0x00786 rsp=SLVERR ack=1 declared=8350 actual=0 start=0x53C9
  [36] invalid RD_NI link=24 addr=0x09F00 rsp=OK ack=0 declared=32934 actual=0 start=0x542C
  [37] invalid RD_NI link=24 addr=0x09F00 rsp=OK ack=0 declared=32934 actual=0 start=0x5433
  [38] invalid WR link=23 addr=0x3E020 rsp=OK ack=0 declared=7232 actual=0 start=0x543C
  [39] invalid WR link=23 addr=0x3E020 rsp=OK ack=0 declared=7232 actual=0 start=0x5444
  [40] invalid RD link=126 addr=0x26941 rsp=SLVERR ack=0 declared=26945 actual=0 start=0x57E6
  [41] invalid RD_NI link=231 addr=0x080E0 rsp=OK ack=0 declared=22496 actual=0 start=0x57F3
  [42] invalid RD link=32 addr=0x0A400 rsp=OK ack=0 declared=224 actual=0 start=0x5831
  [43] invalid WR link=14 addr=0x0A000 rsp=OK ack=0 declared=96 actual=0 start=0x583B
  [44] invalid WR link=14 addr=0x0A000 rsp=OK ack=0 declared=96 actual=0 start=0x5843
warn: scan ended with an incomplete candidate packet
err: timed out waiting for matching secondary reply
`

