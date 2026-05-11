# Phase 5 Injector Datapath Sanity Report

- Timestamp: `2026-04-30T01:21:16`
- SC link: `2`
- Device: `/dev/mudaq0`
- FEB target: `7`
- Source: `real`
- Source emulator mask: `0x0000009F`
- LVDS lane-go mask: `0x00000060`
- LVDS configured by runner: `yes`
- Active emulator lanes: `0x00000000`
- Inject mode: `periodic`
- Injector layout: `legacy_direct`
- Injector base/control offset: `0x0000AC80` / `0` words
- Histogram profile: `delay-mts-both`
- Rate tolerance: `1.000%`
- Real hits per lane for rate expectation: `8`
- Histogram filter enable: `False`
- Histogram filter key loc override: `None`
- Histogram filter key value: `0x00000000`
- MTS expected latency override: `2000`
- MTS delay-ts field override: `t`
- MTS drop-delay-error override: `off`
- Ring filter-inerr override: `on`
- Result: `FAIL`

## Case Summary

| Case | Run | Source | Mode | Interval | Hist Hits | Hist Drops | MTS Hits | Ring InErr | Real Beats | Emu Beats | Class |
|---:|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | 45000 | `real` | `periodic` | 1250 | 316045 | 0 | 2435052 | 41365 | 3196375369 | 3196375369 | `ring_input_errors_with_histogram_hits` |

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
- Pulse high cycles: `4`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000060`
- Histogram ingress status: `0x00000403`
- Histogram profile/readback: `{'profile': 'delay-mts-both', 'description': 'combined signed MTS ts_delta delay histogram on debug_1/debug_2', 'uid': 1212765012, 'meta': 436298157, 'control': 144, 'left_bound': 0, 'right_bound': 4096, 'bin_width': 16, 'key_loc': 639833361, 'key_value': 0, 'interval_cfg': 125000000, 'filter_enable_requested': False, 'filter_key_loc_requested': None, 'filter_key_value_requested': 0}`
- Debug overrides: `{'mts_expected_latency': 2000, 'mts_delay_ts_field': 't', 'mts_drop_delay_error': 'off', 'ring_filter_inerr': 'on', 'mts_ctrl_written': 536870929, 'ring_ctrl_written': 17}`
- Source mux selected beat delta: `3196375369`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `2993819`
- Histogram rate counter source: `live_delta`
- Histogram live delta: `316045` / dropped `0`
- Histogram last interval: `965117` / dropped `0`
- Rate expected/tolerance/error: `0` / `±0` / `0` hits
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000001` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000001` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000000` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000000` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

