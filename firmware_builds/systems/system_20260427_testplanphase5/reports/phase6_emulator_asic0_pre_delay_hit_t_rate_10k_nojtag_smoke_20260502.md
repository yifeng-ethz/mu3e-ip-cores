# Phase 5 Injector Datapath Sanity Report

- Timestamp: `2026-05-02T12:32:37`
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
- Inject mode: `periodic`
- Injector layout: `meta_header`
- Injector base/control offset: `0x0000AC80` / `2` words
- Histogram profile: `delay-hit-t`
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
- MTS discard tolerance: `1.000%`
- Ring filter-inerr override: `keep`
- Result: `FAIL`

## Case Summary

| Case | Run | Source | Mode | Interval | Hist Hits | Hist Drops | MTS Hits | Ring InErr | Real Beats | LVDS Err Δ | DPA Unlock Δ | Class |
|---:|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | 62211 | `emulator` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 0 | n/a | n/a | `exception` |

## Configuration Notes

- The active `mutrig_injector_0` exposes one `coe_inject_pulse` output. The emulator `inject_channel_mask` CSR is still written for visibility, but that mask only affects the separate masked-trigger conduit and is not driven by this injector instance.
- Channel sanity in this report is therefore represented by emulator cluster center/size; ASIC sanity is represented by `active_lanes_mask` and the per-lane source mux selection.
- For `inject-mode=off` with `emulator-hit-mode=periodic`, channel population comes from the emulator's internal channel scan. Choose a rate word that does not phase-lock to the 32-channel scan; rate word `5` only lights a subset, while the current `r53` control lights all 256 bins but is still not uniform enough for rate closure.
- Scoped real-source runs select disabled emulator sources on non-requested lanes; otherwise an aligned idle/live MuTRiG lane can continue into MTS/histogram even when the LVDS lane-go mask requests a single lane.
- The runner writes injector mode `0` before setup and immediately after the injection window because the current injector RTL accepts run-control but does not gate the pulse arbiter by RUNNING.
- The runner autodetects the injector CSR layout. Current programmed images without UID/META use MODE at base+0; packaged images with UID/META use MODE at base+2.

## Per-Case Details

### Case 0

- Run number: `62211`
- Pulse interval: `12500`
- Pulse high cycles: `?`
- Injector mode during run: `?`
- Injector mode after run: `?`
- Lane-go readback: `0x00000000`
- Histogram ingress status: `0x00000000`
- Histogram profile/readback: `{}`
- Debug overrides: `{}`
- Source mux selected beat delta: `0`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
- Histogram rate counter source: `live_delta`
- Histogram live delta: `0` / dropped `0`
- Histogram last interval: `0` / dropped `0`
- JTAG histogram artifact: `{'enabled': False}`
- Rate expected/tolerance/error: `0` / `±0` / `0` hits
- MTS discard/tolerance: `0` / `±0` hits (`n/a` %)
- Post-end clean: `no`
- LVDS error delta lanes: `n/a`
- LVDS DPA unlock delta lanes: `n/a`

- Error: `histogram ingress bridge did not switch to requested stream: base=0x0AB00 target=pre status=0x00000E05 decoded={'raw': 3589, 'live_select_post': 1, 'requested_select_post': 0, 'switch_pending': 1, 'pre_packet_active': 0, 'post_packet_active': 1, 'post_hit_filter_enabled': 1, 'post_hit_region': 1}`

