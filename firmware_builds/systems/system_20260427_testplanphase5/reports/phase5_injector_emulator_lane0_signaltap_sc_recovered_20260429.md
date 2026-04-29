# Phase 5 Injector Datapath Sanity Report

- Timestamp: `2026-04-29T06:34:43`
- SC link: `2`
- Device: `/dev/mudaq0`
- FEB target: `0`
- Source: `emulator`
- Source emulator mask: `0x000000FF`
- Active emulator lanes: `0x00000001`
- Inject mode: `periodic`
- Result: `FAIL`

## Case Summary

| Case | Run | Source | Mode | Interval | Hist Hits | Hist Drops | MTS Hits | Ring InErr | Real Beats | Emu Beats | Class |
|---:|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | 46060 | `emulator` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 0 | 0 | `exception` |

## Configuration Notes

- The active `mutrig_injector_0` exposes one `coe_inject_pulse` output. The emulator `inject_channel_mask` CSR is still written for visibility, but that mask only affects the separate masked-trigger conduit and is not driven by this injector instance.
- Channel sanity in this report is therefore represented by emulator cluster center/size; ASIC sanity is represented by `active_lanes_mask` and the per-lane source mux selection.
- The runner writes injector mode `0` before setup and immediately after the injection window because the current injector RTL accepts run-control but does not gate the pulse arbiter by RUNNING.

## Per-Case Details

### Case 0

- Run number: `46060`
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

- Error: `SC transaction failed after quiet/verbose attempts
quiet rc=4: /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/system_20260427_testplanphase5/bin/sc_tool 2 write 0x0AC80 0x00000000 --quiet --no-reset --reply-timeout-ms 1000
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
  timing main ready   : 63 us
  timing matched      : 0 us
  timing total        : 1000119 us
  secondary before    : 0x2BB0
  secondary after     : 0x2BB0
  secondary delta     : 0 word(s)
  SC main status      : 0x00000001
  SC state            : 0x90000001
err: timed out waiting for matching secondary reply

verbose rc=4: /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/system_20260427_testplanphase5/bin/sc_tool 2 write 0x0AC80 0x00000000 --no-reset --reply-timeout-ms 1000
board:
  PLL_LOCKED_REGISTER_R      = 0x00000000
  LINK_LOCKED_LOW_REGISTER_R = 0x13000000
  LINK_LOCKED_HIGH_REGISTER_R= 0x00002F00
  RESET_LINK_STATUS_REGISTER_R = 0x00000000
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
  timing main ready   : 63 us
  timing matched      : 0 us
  timing total        : 1000989 us
  secondary before    : 0x2BB0
  secondary after     : 0x2BB0
  secondary delta     : 0 word(s)
  SC main status      : 0x00000001
  SC state            : 0x90000001
err: timed out waiting for matching secondary reply
`

