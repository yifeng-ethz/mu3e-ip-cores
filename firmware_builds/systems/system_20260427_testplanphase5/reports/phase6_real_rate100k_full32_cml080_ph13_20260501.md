# Phase 5 Injector Datapath Sanity Report

- Timestamp: `2026-05-01T10:31:05`
- SC link: `2`
- Device: `/dev/mudaq0`
- FEB target: `7`
- Source: `real`
- Source emulator mask: `0x00000000`
- LVDS lane-go mask: `0x000000FF`
- LVDS configured by runner: `yes`
- LVDS SVD snapshot: `yes`
- LVDS per-lane DPA unlock reads: `yes`
- Histogram bin dump: `no`
- JTAG histogram artifact dump: `yes`
- Histogram bin read chunk/delay: `1` words / `1` ms
- Active emulator lanes: `0x00000000`
- Inject mode: `periodic`
- Injector layout: `meta_header`
- Injector base/control offset: `0x0000AC80` / `2` words
- Histogram profile: `rate`
- Histogram ingress source: `pre`
- Rate tolerance: `1.000%`
- Real hits per lane for rate expectation: `32`
- Histogram filter enable: `False`
- Histogram filter key loc override: `None`
- Histogram filter key value: `0x00000000`
- MTS expected latency override: `2000`
- MTS overflow lookback override: `keep`
- MTS bypass-lapse override: `keep`
- MTS delay-ts field override: `t`
- MTS drop-delay-error override: `off`
- Ring filter-inerr override: `on`
- Result: `FAIL`

## Case Summary

| Case | Run | Source | Mode | Interval | Hist Hits | Hist Drops | MTS Hits | Ring InErr | Real Beats | LVDS Err Δ | DPA Unlock Δ | Class |
|---:|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | 48613 | `real` | `periodic` | 1250 | 31948348 | 0 | 365366731 | 349207512 | 14300850119 | 0 | 0 | `mts_discard_with_histogram_hits` |

## Configuration Notes

- The active `mutrig_injector_0` exposes one `coe_inject_pulse` output. The emulator `inject_channel_mask` CSR is still written for visibility, but that mask only affects the separate masked-trigger conduit and is not driven by this injector instance.
- Channel sanity in this report is therefore represented by emulator cluster center/size; ASIC sanity is represented by `active_lanes_mask` and the per-lane source mux selection.
- For `inject-mode=off` with `emulator-hit-mode=periodic`, channel population comes from the emulator's internal channel scan. Choose a rate word that does not phase-lock to the 32-channel scan; rate word `5` only lights a subset, while the current `r53` control lights all 256 bins but is still not uniform enough for rate closure.
- Scoped real-source runs select disabled emulator sources on non-requested lanes; otherwise an aligned idle/live MuTRiG lane can continue into MTS/histogram even when the LVDS lane-go mask requests a single lane.
- The runner writes injector mode `0` before setup and immediately after the injection window because the current injector RTL accepts run-control but does not gate the pulse arbiter by RUNNING.
- The runner autodetects the injector CSR layout. Current programmed images without UID/META use MODE at base+0; packaged images with UID/META use MODE at base+2.

## Per-Case Details

### Case 0

- Run number: `48613`
- Pulse interval: `1250`
- Pulse high cycles: `13`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x000000FF`
- Histogram ingress status: `0x00000400`
- Histogram profile/readback: `{'profile': 'rate', 'description': 'pre-RBCAM hit_type1 global channel/rate histogram', 'toolkit_preset_source': 'toolkits/fe_scifi/board_bring_up/fe_scifi_board_bring_up_project.tcl', 'toolkit_preset_id': 'rate', 'uid': 1212765012, 'meta': 436306421, 'control': 256, 'left_bound': 0, 'right_bound': 256, 'bin_width': 1, 'key_loc': 639837726, 'key_value': 0, 'interval_cfg': 125000000, 'filter_enable_requested': False, 'filter_key_loc_requested': None, 'filter_key_value_requested': 0}`
- Debug overrides: `{'mts_expected_latency': 2000, 'mts_overflow_lookback': None, 'mts_bypass_lapse': 'keep', 'mts_delay_ts_field': 't', 'mts_drop_delay_error': 'off', 'ring_filter_inerr': 'on', 'mts_ctrl_written': 536870929, 'ring_ctrl_written': 17}`
- Source mux selected beat delta: `14300850119`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `296477355`
- Histogram rate counter source: `last_interval`
- Histogram live delta: `11227404` / dropped `0`
- Histogram last interval: `31948348` / dropped `0`
- JTAG histogram artifact: `{'enabled': True, 'profile': 'rate', 'csv': '/home/yifeng/packages/mu3e_ip_dev/.worktrees/mu3e_ip_cores_phase6_closure_20260430/firmware_builds/systems/system_20260427_testplanphase5/reports/phase6_rate_per_channel_1s_real_full32_cml080_ph13_20260501.csv', 'log': '/home/yifeng/packages/mu3e_ip_dev/.worktrees/mu3e_ip_cores_phase6_closure_20260430/firmware_builds/systems/system_20260427_testplanphase5/reports/phase6_rate_per_channel_1s_real_full32_cml080_ph13_20260501.log', 'returncode': 0, 'timed_out': False, 'elapsed_s': 9.223954413086176, 'csv_exists': True, 'csv_line_count': 257}`
- Rate expected/tolerance/error: `25600000` / `±256000` / `6348348` hits
- Post-end clean: `yes`
- LVDS error delta lanes: `[]`
- LVDS DPA unlock delta lanes: `[]`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000000` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000000` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000000` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000000` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000000` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000000` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

| Lane | Go | Mode | Hold | Err Before | Err After | Err Δ | DPA Before | DPA After | DPA Δ |
|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|
| 0 | 1 | `adaptive` | 0 | `0x0000001A` | `0x0000001A` | 0 | 0 | 0 | 0 |
| 1 | 1 | `adaptive` | 0 | `0x0000001A` | `0x0000001A` | 0 | 0 | 0 | 0 |
| 2 | 1 | `adaptive` | 0 | `0x000044A9` | `0x000044A9` | 0 | 0 | 0 | 0 |
| 3 | 1 | `adaptive` | 0 | `0x0000001A` | `0x0000001A` | 0 | 0 | 0 | 0 |
| 4 | 1 | `adaptive` | 0 | `0x000032DA` | `0x000032DA` | 0 | 0 | 0 | 0 |
| 5 | 1 | `adaptive` | 0 | `0x000048E7` | `0x000048E7` | 0 | 0 | 0 | 0 |
| 6 | 1 | `adaptive` | 0 | `0x0000001A` | `0x0000001A` | 0 | 0 | 0 | 0 |
| 7 | 1 | `adaptive` | 0 | `0x0000001A` | `0x0000001A` | 0 | 0 | 0 | 0 |

