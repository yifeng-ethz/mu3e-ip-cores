# Phase 5 Injector Datapath Sanity Report

- Timestamp: `2026-04-28T11:57:33`
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
| 0 | 45000 | `emulator` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3347940185 | 3347940185 | `blocked_before_mts` |

## Configuration Notes

- The active `mutrig_injector_0` exposes one `coe_inject_pulse` output. The emulator `inject_channel_mask` CSR is still written for visibility, but that mask only affects the separate masked-trigger conduit and is not driven by this injector instance.
- Channel sanity in this report is therefore represented by emulator cluster center/size; ASIC sanity is represented by `active_lanes_mask` and the per-lane source mux selection.
- The runner writes injector mode `0` before setup and immediately after the injection window because the current injector RTL accepts run-control but does not gate the pulse arbiter by RUNNING.

## Per-Case Details

### Case 0

- Run number: `45000`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode after run: `0`
- Lane-go readback: `0x000001FF`
- Histogram ingress status: `0x00000E03`
- Source mux selected beat delta: `3347940185`
- Emulator frame delta: `59451`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000001` | 1 | `0x00000001` | `0x20041001` | `0x00002ECC` |
| 1 | `0x00000001` | 1 | `0x00000001` | `0x20441001` | `0x00002ECC` |
| 2 | `0x00000001` | 1 | `0x00000001` | `0x20841001` | `0x00002ECC` |
| 3 | `0x00000001` | 1 | `0x00000001` | `0x20C41001` | `0x00002ECC` |
| 4 | `0x00000001` | 1 | `0x00000001` | `0x21041001` | `0x00002ECC` |
| 5 | `0x00000001` | 1 | `0x00000001` | `0x21441001` | `0x00002ECC` |
| 6 | `0x00000001` | 1 | `0x00000001` | `0x21841001` | `0x00002ECC` |
| 7 | `0x00000001` | 1 | `0x00000001` | `0x21C41001` | `0x00002ECC` |

