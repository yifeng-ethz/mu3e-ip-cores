# Phase 5 Injector Datapath Sanity Report

- Timestamp: `2026-04-29T06:26:12`
- SC link: `2`
- Device: `/dev/mudaq0`
- FEB target: `0`
- Source: `emulator`
- Source emulator mask: `0x000000FF`
- Active emulator lanes: `0x00000001`
- Inject mode: `periodic`
- Result: `PASS`

## Case Summary

| Case | Run | Source | Mode | Interval | Hist Hits | Hist Drops | MTS Hits | Ring InErr | Real Beats | Emu Beats | Class |
|---:|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | 46000 | `emulator` | `periodic` | 12500 | 29831 | 0 | 22420 | 0 | 3098033910 | 3098033910 | `PASS` |

## Configuration Notes

- The active `mutrig_injector_0` exposes one `coe_inject_pulse` output. The emulator `inject_channel_mask` CSR is still written for visibility, but that mask only affects the separate masked-trigger conduit and is not driven by this injector instance.
- Channel sanity in this report is therefore represented by emulator cluster center/size; ASIC sanity is represented by `active_lanes_mask` and the per-lane source mux selection.
- The runner writes injector mode `0` before setup and immediately after the injection window because the current injector RTL accepts run-control but does not gate the pulse arbiter by RUNNING.

## Per-Case Details

### Case 0

- Run number: `46000`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x000001FF`
- Histogram ingress status: `0x00000403`
- Source mux selected beat delta: `3098033910`
- Emulator frame delta: `52760`
- Frame CRC delta: `0`
- Frame actual-hit delta: `28619`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000001` | 1 | `0x00000001` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000001` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

