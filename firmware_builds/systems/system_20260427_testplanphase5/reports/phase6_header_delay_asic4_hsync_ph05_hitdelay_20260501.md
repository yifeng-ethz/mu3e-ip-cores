# Phase 5 Injector Datapath Sanity Report

- Timestamp: `2026-05-01T17:46:21`
- SC link: `2`
- Device: `/dev/mudaq0`
- FEB target: `7`
- Source: `real`
- Source emulator mask: `0x000000EF`
- LVDS lane-go mask: `0x00000010`
- LVDS configured by runner: `yes`
- LVDS SVD snapshot: `yes`
- LVDS per-lane DPA unlock reads: `yes`
- Histogram bin dump: `no`
- JTAG histogram artifact dump: `yes`
- Histogram bin read chunk/delay: `1` words / `1` ms
- Active emulator lanes: `0x00000000`
- Inject mode: `header`
- Injector layout: `meta_header`
- Injector base/control offset: `0x0000AC80` / `2` words
- Histogram profile: `delay-hit-t`
- Histogram ingress source: `pre`
- Rate tolerance: `1.000%`
- Real hits per lane for rate expectation: `1`
- Histogram filter enable: `True`
- Histogram filter key loc override: `None`
- Histogram filter key value: `0x00000004`
- MTS expected latency override: `2000`
- MTS overflow lookback override: `keep`
- MTS bypass-lapse override: `keep`
- MTS delay-ts field override: `t`
- MTS drop-delay-error override: `off`
- MTS discard tolerance: `1.000%`
- Ring filter-inerr override: `on`
- Result: `PASS`

## Case Summary

| Case | Run | Source | Mode | Interval | Hist Hits | Hist Drops | MTS Hits | Ring InErr | Real Beats | LVDS Err Δ | DPA Unlock Δ | Class |
|---:|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | 45000 | `real` | `header` | 12500 | 2254336 | 0 | 46468992 | 0 | 13253058053 | 0 | 0 | `PASS` |

## Configuration Notes

- The active `mutrig_injector_0` exposes one `coe_inject_pulse` output. The emulator `inject_channel_mask` CSR is still written for visibility, but that mask only affects the separate masked-trigger conduit and is not driven by this injector instance.
- Channel sanity in this report is therefore represented by emulator cluster center/size; ASIC sanity is represented by `active_lanes_mask` and the per-lane source mux selection.
- For `inject-mode=off` with `emulator-hit-mode=periodic`, channel population comes from the emulator's internal channel scan. Choose a rate word that does not phase-lock to the 32-channel scan; rate word `5` only lights a subset, while the current `r53` control lights all 256 bins but is still not uniform enough for rate closure.
- Scoped real-source runs select disabled emulator sources on non-requested lanes; otherwise an aligned idle/live MuTRiG lane can continue into MTS/histogram even when the LVDS lane-go mask requests a single lane.
- The runner writes injector mode `0` before setup and immediately after the injection window because the current injector RTL accepts run-control but does not gate the pulse arbiter by RUNNING.
- The runner autodetects the injector CSR layout. Current programmed images without UID/META use MODE at base+0; packaged images with UID/META use MODE at base+2.

## Per-Case Details

### Case 0

- Run number: `45000`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `1`
- Injector mode after run: `0`
- Lane-go readback: `0x00000010`
- Histogram ingress status: `0x00000400`
- Histogram profile/readback: `{'profile': 'delay-hit-t', 'description': 'normal hit_type1 T-delay histogram with native ASIC/channel filtering', 'toolkit_preset_source': 'toolkits/fe_scifi/board_bring_up/fe_scifi_board_bring_up_project.tcl', 'toolkit_preset_id': 'delay_hit_t', 'uid': 1212765012, 'meta': 436306421, 'control': 4112, 'left_bound': 4294966296, 'right_bound': 3096, 'bin_width': 16, 'key_loc': 639837726, 'key_value': 262144, 'interval_cfg': 125000000, 'filter_enable_requested': True, 'filter_key_loc_requested': None, 'filter_key_value_requested': 4}`
- Debug overrides: `{'mts_expected_latency': 2000, 'mts_overflow_lookback': None, 'mts_bypass_lapse': 'keep', 'mts_delay_ts_field': 't', 'mts_drop_delay_error': 'off', 'ring_filter_inerr': 'on', 'mts_ctrl_written': 536870929, 'ring_ctrl_written': 17}`
- Source mux selected beat delta: `13253058053`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `49328960`
- Histogram rate counter source: `live_delta`
- Histogram live delta: `2254336` / dropped `0`
- Histogram last interval: `4395616` / dropped `0`
- JTAG histogram artifact: `{'enabled': True, 'profile': 'delay-hit-t', 'csv': '/home/yifeng/packages/mu3e_ip_dev/.worktrees/mu3e_ip_cores_phase6_closure_20260430/firmware_builds/systems/system_20260427_testplanphase5/reports/phase6_header_delay_asic4_hsync_ph05_hitdelay_20260501.csv', 'log': '/home/yifeng/packages/mu3e_ip_dev/.worktrees/mu3e_ip_cores_phase6_closure_20260430/firmware_builds/systems/system_20260427_testplanphase5/reports/phase6_header_delay_asic4_hsync_ph05_hitdelay_20260501.log', 'returncode': 0, 'timed_out': False, 'elapsed_s': 8.17380478605628, 'csv_exists': True, 'csv_line_count': 257}`
- Rate expected/tolerance/error: `0` / `±0` / `0` hits
- MTS discard/tolerance: `0` / `±464690` hits (`0.0` %)
- Post-end clean: `yes`
- LVDS error delta lanes: `[]`
- LVDS DPA unlock delta lanes: `[]`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000001` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000001` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000000` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

| Lane | Go | Mode | Hold | Err Before | Err After | Err Δ | DPA Before | DPA After | DPA Δ |
|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0 | `adaptive` | 0 | `0x00000088` | `0x00000088` | 0 | 0 | 0 | 0 |
| 1 | 0 | `adaptive` | 0 | `0x00000088` | `0x00000088` | 0 | 0 | 0 | 0 |
| 2 | 0 | `adaptive` | 0 | `0x00004517` | `0x00004517` | 0 | 0 | 0 | 0 |
| 3 | 0 | `adaptive` | 0 | `0x00000088` | `0x00000088` | 0 | 0 | 0 | 0 |
| 4 | 1 | `adaptive` | 0 | `0x00003348` | `0x00003348` | 0 | 0 | 0 | 0 |
| 5 | 0 | `adaptive` | 0 | `0x00004955` | `0x00004955` | 0 | 0 | 0 | 0 |
| 6 | 0 | `adaptive` | 0 | `0x00000088` | `0x00000088` | 0 | 0 | 0 | 0 |
| 7 | 0 | `adaptive` | 0 | `0x00000088` | `0x00000088` | 0 | 0 | 0 | 0 |

