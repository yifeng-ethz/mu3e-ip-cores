# Phase 5 Injector Datapath Sanity Report

- Timestamp: `2026-04-29T19:44:46`
- SC link: `2`
- Device: `/dev/mudaq0`
- FEB target: `7`
- Source: `real`
- Source emulator mask: `0x00000000`
- LVDS lane-go mask: `0x00000001`
- LVDS configured by runner: `no`
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
| 0 | 49400 | `real` | `periodic` | 1250 | 170117 | 0 | 1646677 | 771 | 4131851278 | 4131851278 | `mts_discard_with_histogram_hits` |

## Configuration Notes

- The active `mutrig_injector_0` exposes one `coe_inject_pulse` output. The emulator `inject_channel_mask` CSR is still written for visibility, but that mask only affects the separate masked-trigger conduit and is not driven by this injector instance.
- Channel sanity in this report is therefore represented by emulator cluster center/size; ASIC sanity is represented by `active_lanes_mask` and the per-lane source mux selection.
- The runner writes injector mode `0` before setup and immediately after the injection window because the current injector RTL accepts run-control but does not gate the pulse arbiter by RUNNING.

## Per-Case Details

### Case 0

- Run number: `49400`
- Pulse interval: `1250`
- Pulse high cycles: `8`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000001`
- Histogram ingress status: `0x00000403`
- Histogram profile/readback: `{'profile': 'rate', 'description': 'post-hit channel/rate histogram', 'uid': 1212765012, 'meta': 436289965, 'control': 4352, 'left_bound': 0, 'right_bound': 256, 'bin_width': 1, 'key_loc': 639837726, 'key_value': 16, 'interval_cfg': 125000000, 'filter_enable_requested': True, 'filter_key_loc_requested': None, 'filter_key_value_requested': 16}`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `4131851278`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `1235648`
- Post-end clean: `yes`

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

