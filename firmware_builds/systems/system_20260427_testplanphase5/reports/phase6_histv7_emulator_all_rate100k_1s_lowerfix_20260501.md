# Phase 5 Injector Datapath Sanity Report

- Timestamp: `2026-05-01T05:50:20`
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
- JTAG histogram artifact dump: `no`
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
- MTS bypass-lapse override: `keep`
- MTS delay-ts field override: `keep`
- MTS drop-delay-error override: `keep`
- Ring filter-inerr override: `keep`
- Result: `PASS`

## Case Summary

| Case | Run | Source | Mode | Interval | Hist Hits | Hist Drops | MTS Hits | Ring InErr | Real Beats | LVDS Err Δ | DPA Unlock Δ | Class |
|---:|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | 46130 | `emulator` | `periodic` | 1250 | 798728 | 0 | 2465060 | 0 | 3846190596 | n/a | n/a | `PASS` |

## Configuration Notes

- The active `mutrig_injector_0` exposes one `coe_inject_pulse` output. The emulator `inject_channel_mask` CSR is still written for visibility, but that mask only affects the separate masked-trigger conduit and is not driven by this injector instance.
- Channel sanity in this report is therefore represented by emulator cluster center/size; ASIC sanity is represented by `active_lanes_mask` and the per-lane source mux selection.
- Scoped real-source runs select disabled emulator sources on non-requested lanes; otherwise an aligned idle/live MuTRiG lane can continue into MTS/histogram even when the LVDS lane-go mask requests a single lane.
- The runner writes injector mode `0` before setup and immediately after the injection window because the current injector RTL accepts run-control but does not gate the pulse arbiter by RUNNING.
- The runner autodetects the injector CSR layout. Current programmed images without UID/META use MODE at base+0; packaged images with UID/META use MODE at base+2.

## Per-Case Details

### Case 0

- Run number: `46130`
- Pulse interval: `1250`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x000001FF`
- Histogram ingress status: `0x00000C00`
- Histogram profile/readback: `{'profile': 'rate', 'description': 'pre-RBCAM hit_type1 global channel/rate histogram', 'toolkit_preset_source': 'toolkits/fe_scifi/board_bring_up/fe_scifi_board_bring_up_project.tcl', 'toolkit_preset_id': 'rate', 'uid': 1212765012, 'meta': 436302325, 'control': 256, 'left_bound': 0, 'right_bound': 256, 'bin_width': 1, 'key_loc': 639837726, 'key_value': 0, 'interval_cfg': 125000000, 'filter_enable_requested': False, 'filter_key_loc_requested': None, 'filter_key_value_requested': 0}`
- Debug overrides: `{'mts_expected_latency': None, 'mts_bypass_lapse': 'keep', 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3846190596`
- Emulator frame delta: `374040`
- Frame CRC delta: `0`
- Frame actual-hit delta: `2912700`
- Histogram rate counter source: `last_interval`
- Histogram live delta: `577640` / dropped `0`
- Histogram last interval: `798728` / dropped `0`
- JTAG histogram artifact: `{'enabled': False}`
- Rate expected/tolerance/error: `800000` / `±8000` / `-1272` hits
- Post-end clean: `yes`
- LVDS error delta lanes: `n/a`
- LVDS DPA unlock delta lanes: `n/a`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000001` | 1 | `0x00000001` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 1 | `0x00000001` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 1 | `0x00000001` | `0x20841001` | `0x00000000` |
| 3 | `0x00000001` | 1 | `0x00000001` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 1 | `0x00000001` | `0x21041001` | `0x0000BF1C` |
| 5 | `0x00000001` | 1 | `0x00000001` | `0x21441001` | `0x0000BF1C` |
| 6 | `0x00000001` | 1 | `0x00000001` | `0x21841001` | `0x0000BF1C` |
| 7 | `0x00000001` | 1 | `0x00000001` | `0x21C41001` | `0x0000BF1C` |

- LVDS snapshot error: `{'captured': False}`

