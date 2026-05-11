# Phase 5 Injector Datapath Sanity Report

- Timestamp: `2026-05-02T12:35:11`
- SC link: `2`
- Device: `/dev/mudaq0`
- FEB target: `7`
- Source: `emulator`
- Source emulator mask: `0x000000FF`
- LVDS lane-go mask: `0x00000000`
- LVDS configured by runner: `yes`
- LVDS SVD snapshot: `no`
- LVDS per-lane DPA unlock reads: `no`
- Histogram bin dump: `no`
- JTAG histogram artifact dump: `no`
- Histogram bin read chunk/delay: `1` words / `1` ms
- Active emulator lanes: `0x00000001`
- Inject mode: `off`
- Injector layout: `meta_header`
- Injector base/control offset: `0x0000AC80` / `2` words
- Histogram profile: `delay-hit-t`
- Histogram ingress source: `post`
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
- MTS discard tolerance: `1.000%`
- Ring filter-inerr override: `keep`
- Result: `FAIL`

## Case Summary

| Case | Run | Source | Mode | Interval | Hist Hits | Hist Drops | MTS Hits | Ring InErr | Real Beats | LVDS Err Δ | DPA Unlock Δ | Class |
|---:|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | 62213 | `emulator` | `off` | 12500 | 4293755587 | 0 | 19062439 | 12498049 | 3790964824 | n/a | n/a | `ring_input_errors_with_histogram_hits` |

## Configuration Notes

- The active `mutrig_injector_0` exposes one `coe_inject_pulse` output. The emulator `inject_channel_mask` CSR is still written for visibility, but that mask only affects the separate masked-trigger conduit and is not driven by this injector instance.
- Channel sanity in this report is therefore represented by emulator cluster center/size; ASIC sanity is represented by `active_lanes_mask` and the per-lane source mux selection.
- For `inject-mode=off` with `emulator-hit-mode=periodic`, channel population comes from the emulator's internal channel scan. Choose a rate word that does not phase-lock to the 32-channel scan; rate word `5` only lights a subset, while the current `r53` control lights all 256 bins but is still not uniform enough for rate closure.
- Scoped real-source runs select disabled emulator sources on non-requested lanes; otherwise an aligned idle/live MuTRiG lane can continue into MTS/histogram even when the LVDS lane-go mask requests a single lane.
- The runner writes injector mode `0` before setup and immediately after the injection window because the current injector RTL accepts run-control but does not gate the pulse arbiter by RUNNING.
- The runner autodetects the injector CSR layout. Current programmed images without UID/META use MODE at base+0; packaged images with UID/META use MODE at base+2.

## Per-Case Details

### Case 0

- Run number: `62213`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `0`
- Injector mode after run: `0`
- Lane-go readback: `0x00000000`
- Histogram ingress status: `0x00000E03`
- Histogram profile/readback: `{'profile': 'delay-hit-t', 'description': 'normal hit_type1 T-delay histogram with native ASIC/channel filtering', 'toolkit_preset_source': 'toolkits/fe_scifi/board_bring_up/fe_scifi_board_bring_up_project.tcl', 'toolkit_preset_id': 'delay_hit_t', 'uid': 1212765012, 'meta': 436306422, 'control': 16, 'left_bound': 4294966296, 'right_bound': 3096, 'bin_width': 16, 'key_loc': 639837726, 'key_value': 0, 'interval_cfg': 125000000, 'filter_enable_requested': False, 'filter_key_loc_requested': None, 'filter_key_value_requested': 0}`
- Debug overrides: `{'mts_expected_latency': None, 'mts_overflow_lookback': None, 'mts_bypass_lapse': 'keep', 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3790964824`
- Emulator frame delta: `43041`
- Frame CRC delta: `0`
- Frame actual-hit delta: `15779325`
- Histogram rate counter source: `live_delta`
- Histogram live delta: `4293755587` / dropped `0`
- Histogram last interval: `4245571` / dropped `0`
- JTAG histogram artifact: `{'enabled': False}`
- Rate expected/tolerance/error: `0` / `±0` / `0` hits
- MTS discard/tolerance: `0` / `±190624` hits (`0.0` %)
- Post-end clean: `yes`
- LVDS error delta lanes: `n/a`
- LVDS DPA unlock delta lanes: `n/a`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000001` | 1 | `0x00000007` | `0x2004101F` | `0x00007FDD` |
| 1 | `0x00000001` | 0 | `0x00000006` | `0x2044101F` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000006` | `0x2084101F` | `0x00000000` |
| 3 | `0x00000001` | 0 | `0x00000006` | `0x20C4101F` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000006` | `0x2104101F` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000006` | `0x2144101F` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000006` | `0x2184101F` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000006` | `0x21C4101F` | `0x00000000` |

- LVDS snapshot error: `{'captured': False}`

