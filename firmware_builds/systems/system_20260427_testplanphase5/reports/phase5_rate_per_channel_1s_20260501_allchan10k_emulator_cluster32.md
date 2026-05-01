# Phase 5 Injector Datapath Sanity Report

- Timestamp: `2026-05-01T08:30:15`
- SC link: `2`
- Device: `/dev/mudaq0`
- FEB target: `7`
- Source: `emulator`
- Source emulator mask: `0x000000FF`
- LVDS lane-go mask: `0x000001FF`
- LVDS configured by runner: `yes`
- LVDS SVD snapshot: `no`
- LVDS per-lane DPA unlock reads: `no`
- Histogram bin dump: `no`
- JTAG histogram artifact dump: `yes`
- Histogram bin read chunk/delay: `1` words / `1` ms
- Active emulator lanes: `0x000000FF`
- Inject mode: `periodic`
- Injector layout: `meta_header`
- Injector base/control offset: `0x0000AC80` / `2` words
- Histogram profile: `rate`
- Histogram ingress source: `pre`
- Rate tolerance: `1.000%`
- Real hits per lane for rate expectation: `1`
- Histogram filter enable: `False`
- Histogram filter key loc override: `None`
- Histogram filter key value: `0x00000000`
- MTS expected latency override: `keep`
- MTS overflow lookback override: `keep`
- MTS bypass-lapse override: `keep`
- MTS delay-ts field override: `keep`
- MTS drop-delay-error override: `keep`
- Ring filter-inerr override: `keep`
- Result: `FAIL`

## Case Summary

| Case | Run | Source | Mode | Interval | Hist Hits | Hist Drops | MTS Hits | Ring InErr | Real Beats | LVDS Err Δ | DPA Unlock Δ | Class |
|---:|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | 45000 | `emulator` | `periodic` | 12500 | 79992 | 0 | 838192 | 0 | 11152024645 | n/a | n/a | `rate_out_of_tolerance` |

## Configuration Notes

- The active `mutrig_injector_0` exposes one `coe_inject_pulse` output. The emulator `inject_channel_mask` CSR is still written for visibility, but that mask only affects the separate masked-trigger conduit and is not driven by this injector instance.
- Channel sanity in this report is therefore represented by emulator cluster center/size; ASIC sanity is represented by `active_lanes_mask` and the per-lane source mux selection.
- Scoped real-source runs select disabled emulator sources on non-requested lanes; otherwise an aligned idle/live MuTRiG lane can continue into MTS/histogram even when the LVDS lane-go mask requests a single lane.
- The runner writes injector mode `0` before setup and immediately after the injection window because the current injector RTL accepts run-control but does not gate the pulse arbiter by RUNNING.
- The runner autodetects the injector CSR layout. Current programmed images without UID/META use MODE at base+0; packaged images with UID/META use MODE at base+2.

## Per-Case Details

### Case 0

- Run number: `45000`
- Pulse interval: `12500`
- Pulse high cycles: `8`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x000001FF`
- Histogram ingress status: `0x00000400`
- Histogram profile/readback: `{'profile': 'rate', 'description': 'pre-RBCAM hit_type1 global channel/rate histogram', 'toolkit_preset_source': 'toolkits/fe_scifi/board_bring_up/fe_scifi_board_bring_up_project.tcl', 'toolkit_preset_id': 'rate', 'uid': 1212765012, 'meta': 436302325, 'control': 256, 'left_bound': 0, 'right_bound': 256, 'bin_width': 1, 'key_loc': 639837726, 'key_value': 0, 'interval_cfg': 125000000, 'filter_enable_requested': False, 'filter_key_loc_requested': None, 'filter_key_value_requested': 0}`
- Debug overrides: `{'mts_expected_latency': None, 'mts_overflow_lookback': None, 'mts_bypass_lapse': 'keep', 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `11152024645`
- Emulator frame delta: `369474`
- Frame CRC delta: `0`
- Frame actual-hit delta: `886084`
- Histogram rate counter source: `last_interval`
- Histogram live delta: `29784` / dropped `0`
- Histogram last interval: `79992` / dropped `0`
- JTAG histogram artifact: `{'enabled': True, 'profile': 'rate', 'csv': '/home/yifeng/packages/mu3e_ip_dev/.worktrees/mu3e_ip_cores_phase6_closure_20260430/firmware_builds/systems/system_20260427_testplanphase5/reports/phase5_rate_per_channel_1s_20260501_allchan10k_emulator_cluster32.csv', 'log': '/home/yifeng/packages/mu3e_ip_dev/.worktrees/mu3e_ip_cores_phase6_closure_20260430/firmware_builds/systems/system_20260427_testplanphase5/reports/phase5_rate_per_channel_1s_20260501_allchan10k_emulator_cluster32.log', 'returncode': 0, 'timed_out': False, 'elapsed_s': 8.17511373013258, 'csv_exists': True, 'csv_line_count': 257}`
- Rate expected/tolerance/error: `2560000` / `±25600` / `-2480008` hits
- Post-end clean: `yes`
- LVDS error delta lanes: `n/a`
- LVDS DPA unlock delta lanes: `n/a`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000001` | 1 | `0x00000001` | `0x20041000` | `0x0000D805` |
| 1 | `0x00000001` | 1 | `0x00000001` | `0x20441000` | `0x0000D805` |
| 2 | `0x00000001` | 1 | `0x00000001` | `0x20841000` | `0x0000D805` |
| 3 | `0x00000001` | 1 | `0x00000001` | `0x20C41000` | `0x0000D805` |
| 4 | `0x00000001` | 1 | `0x00000001` | `0x21041000` | `0x0000D805` |
| 5 | `0x00000001` | 1 | `0x00000001` | `0x21441000` | `0x0000D805` |
| 6 | `0x00000001` | 1 | `0x00000001` | `0x21841000` | `0x0000D805` |
| 7 | `0x00000001` | 1 | `0x00000001` | `0x21C41000` | `0x0000D805` |

- LVDS snapshot error: `{'captured': False}`
