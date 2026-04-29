# Phase 5 Injector Datapath Sanity Report

- Timestamp: `2026-04-29T10:19:31`
- SC link: `2`
- Device: `/dev/mudaq0`
- FEB target: `7`
- Source: `mixed`
- Source emulator mask: `0x000000F6`
- LVDS lane-go mask: `0x00000009`
- Active emulator lanes: `0x00000000`
- Inject mode: `periodic`
- MTS expected latency override: `keep`
- MTS delay-ts field override: `keep`
- MTS drop-delay-error override: `keep`
- Ring filter-inerr override: `keep`
- Result: `PASS`

## Case Summary

| Case | Run | Source | Mode | Interval | Hist Hits | Hist Drops | MTS Hits | Ring InErr | Real Beats | Emu Beats | Class |
|---:|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | 47200 | `mixed` | `periodic` | 12500 | 32253 | 0 | 24908 | 0 | 3239355226 | 3239355226 | `PASS` |
| 1 | 47201 | `mixed` | `periodic` | 12500 | 30823 | 0 | 24594 | 0 | 3329763418 | 3329763418 | `PASS` |
| 2 | 47202 | `mixed` | `periodic` | 12500 | 30283 | 0 | 24654 | 0 | 3202355114 | 3202355114 | `PASS` |
| 3 | 47203 | `mixed` | `periodic` | 12500 | 29424 | 0 | 23992 | 0 | 3236674294 | 3236674294 | `PASS` |
| 4 | 47204 | `mixed` | `periodic` | 12500 | 29975 | 0 | 24384 | 0 | 3220873058 | 3220873058 | `PASS` |
| 5 | 47205 | `mixed` | `periodic` | 12500 | 30174 | 0 | 24736 | 0 | 3225903234 | 3225903234 | `PASS` |
| 6 | 47206 | `mixed` | `periodic` | 12500 | 30570 | 0 | 23902 | 0 | 3203325484 | 3203325484 | `PASS` |
| 7 | 47207 | `mixed` | `periodic` | 12500 | 31786 | 0 | 24251 | 0 | 3278256517 | 3278256517 | `PASS` |
| 8 | 47208 | `mixed` | `periodic` | 12500 | 33417 | 0 | 24943 | 0 | 3383980205 | 3383980205 | `PASS` |
| 9 | 47209 | `mixed` | `periodic` | 12500 | 31287 | 0 | 24045 | 0 | 4323448259 | 4323448259 | `PASS` |
| 10 | 47210 | `mixed` | `periodic` | 12500 | 29711 | 0 | 24028 | 0 | 3244903593 | 3244903593 | `PASS` |
| 11 | 47211 | `mixed` | `periodic` | 12500 | 30809 | 0 | 25650 | 0 | 3286299391 | 3286299391 | `PASS` |
| 12 | 47212 | `mixed` | `periodic` | 12500 | 29571 | 0 | 24529 | 0 | 3250978538 | 3250978538 | `PASS` |
| 13 | 47213 | `mixed` | `periodic` | 12500 | 29708 | 0 | 24327 | 0 | 3207219717 | 3207219717 | `PASS` |
| 14 | 47214 | `mixed` | `periodic` | 12500 | 32066 | 0 | 25230 | 0 | 3194925007 | 3194925007 | `PASS` |
| 15 | 47215 | `mixed` | `periodic` | 12500 | 31754 | 0 | 24612 | 0 | 3299436675 | 3299436675 | `PASS` |
| 16 | 47216 | `mixed` | `periodic` | 12500 | 32361 | 0 | 24894 | 0 | 3337918212 | 3337918212 | `PASS` |
| 17 | 47217 | `mixed` | `periodic` | 12500 | 52587 | 0 | 45692 | 0 | 3214869863 | 3214869863 | `PASS` |
| 18 | 47218 | `mixed` | `periodic` | 12500 | 30621 | 0 | 24651 | 0 | 3316992984 | 3316992984 | `PASS` |
| 19 | 47219 | `mixed` | `periodic` | 12500 | 51537 | 0 | 46449 | 0 | 5455695996 | 5455695996 | `PASS` |
| 20 | 47220 | `mixed` | `periodic` | 12500 | 31817 | 0 | 24597 | 0 | 3243813255 | 3243813255 | `PASS` |
| 21 | 47221 | `mixed` | `periodic` | 12500 | 29342 | 0 | 24467 | 0 | 3242878354 | 3242878354 | `PASS` |
| 22 | 47222 | `mixed` | `periodic` | 12500 | 30796 | 0 | 24522 | 0 | 3312752032 | 3312752032 | `PASS` |
| 23 | 47223 | `mixed` | `periodic` | 12500 | 31038 | 0 | 25365 | 0 | 3365761299 | 3365761299 | `PASS` |
| 24 | 47224 | `mixed` | `periodic` | 12500 | 33095 | 0 | 24871 | 0 | 4389413330 | 4389413330 | `PASS` |
| 25 | 47225 | `mixed` | `periodic` | 12500 | 32025 | 0 | 25868 | 0 | 3352453282 | 3352453282 | `PASS` |
| 26 | 47226 | `mixed` | `periodic` | 12500 | 29725 | 0 | 24250 | 0 | 3299934517 | 3299934517 | `PASS` |
| 27 | 47227 | `mixed` | `periodic` | 12500 | 33294 | 0 | 25794 | 0 | 4006791975 | 4006791975 | `PASS` |
| 28 | 47228 | `mixed` | `periodic` | 12500 | 41692 | 0 | 24520 | 0 | 3224587439 | 3224587439 | `PASS` |
| 29 | 47229 | `mixed` | `periodic` | 12500 | 30513 | 0 | 24643 | 0 | 3160476220 | 3160476220 | `PASS` |
| 30 | 47230 | `mixed` | `periodic` | 12500 | 31007 | 0 | 25636 | 0 | 3284188554 | 3284188554 | `PASS` |
| 31 | 47231 | `mixed` | `periodic` | 12500 | 32209 | 0 | 25409 | 0 | 3329167036 | 3329167036 | `PASS` |
| 32 | 47232 | `mixed` | `periodic` | 12500 | 32201 | 0 | 25118 | 0 | 3706240045 | 3706240045 | `PASS` |
| 33 | 47233 | `mixed` | `periodic` | 12500 | 31454 | 0 | 24428 | 0 | 3307385401 | 3307385401 | `PASS` |
| 34 | 47234 | `mixed` | `periodic` | 12500 | 31060 | 0 | 24533 | 0 | 3247167986 | 3247167986 | `PASS` |
| 35 | 47235 | `mixed` | `periodic` | 12500 | 31309 | 0 | 24273 | 0 | 3357415551 | 3357415551 | `PASS` |
| 36 | 47236 | `mixed` | `periodic` | 12500 | 43697 | 0 | 36965 | 0 | 4387751615 | 4387751615 | `PASS` |
| 37 | 47237 | `mixed` | `periodic` | 12500 | 34165 | 0 | 26726 | 0 | 3414044989 | 3414044989 | `PASS` |
| 38 | 47238 | `mixed` | `periodic` | 12500 | 31255 | 0 | 24456 | 0 | 3308067633 | 3308067633 | `PASS` |
| 39 | 47239 | `mixed` | `periodic` | 12500 | 31278 | 0 | 23598 | 0 | 3254362108 | 3254362108 | `PASS` |

## Configuration Notes

- The active `mutrig_injector_0` exposes one `coe_inject_pulse` output. The emulator `inject_channel_mask` CSR is still written for visibility, but that mask only affects the separate masked-trigger conduit and is not driven by this injector instance.
- Channel sanity in this report is therefore represented by emulator cluster center/size; ASIC sanity is represented by `active_lanes_mask` and the per-lane source mux selection.
- The runner writes injector mode `0` before setup and immediately after the injection window because the current injector RTL accepts run-control but does not gate the pulse arbiter by RUNNING.

## Per-Case Details

### Case 0

- Run number: `47200`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3239355226`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `31073`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 1

- Run number: `47201`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000603`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3329763418`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `30898`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 2

- Run number: `47202`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3202355114`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `31033`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 3

- Run number: `47203`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3236674294`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `29702`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 4

- Run number: `47204`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3220873058`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `30630`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 5

- Run number: `47205`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3225903234`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `30663`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 6

- Run number: `47206`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3203325484`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `29813`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 7

- Run number: `47207`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3278256517`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `30639`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 8

- Run number: `47208`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3383980205`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `32086`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 9

- Run number: `47209`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `4323448259`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `30016`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 10

- Run number: `47210`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3244903593`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `29961`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 11

- Run number: `47211`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000603`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3286299391`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `31531`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 12

- Run number: `47212`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3250978538`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `30493`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 13

- Run number: `47213`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3207219717`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `30153`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 14

- Run number: `47214`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3194925007`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `31141`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 15

- Run number: `47215`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3299436675`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `30676`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 16

- Run number: `47216`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3337918212`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `31138`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 17

- Run number: `47217`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3214869863`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `52107`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 18

- Run number: `47218`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3316992984`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `30573`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 19

- Run number: `47219`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `5455695996`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `52652`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 20

- Run number: `47220`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3243813255`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `31088`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 21

- Run number: `47221`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3242878354`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `30132`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 22

- Run number: `47222`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3312752032`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `30400`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 23

- Run number: `47223`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3365761299`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `31161`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 24

- Run number: `47224`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `4389413330`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `32004`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 25

- Run number: `47225`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3352453282`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `32552`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 26

- Run number: `47226`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3299934517`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `30139`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 27

- Run number: `47227`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `4006791975`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `32059`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 28

- Run number: `47228`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3224587439`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `42302`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 29

- Run number: `47229`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3160476220`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `30776`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 30

- Run number: `47230`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3284188554`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `31819`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 31

- Run number: `47231`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3329167036`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `31484`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 32

- Run number: `47232`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3706240045`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `31061`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 33

- Run number: `47233`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3307385401`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `30299`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 34

- Run number: `47234`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3247167986`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `30789`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 35

- Run number: `47235`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3357415551`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `30133`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 36

- Run number: `47236`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `4387751615`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `43187`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 37

- Run number: `47237`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3414044989`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `32795`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 38

- Run number: `47238`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3308067633`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `30442`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |

### Case 39

- Run number: `47239`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3254362108`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `29636`
- Post-end clean: `yes`

| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |
|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000000` | 0 | `0x00000000` | `0x20041001` | `0x00000000` |
| 1 | `0x00000001` | 0 | `0x00000000` | `0x20441001` | `0x00000000` |
| 2 | `0x00000001` | 0 | `0x00000000` | `0x20841001` | `0x00000000` |
| 3 | `0x00000000` | 0 | `0x00000000` | `0x20C41001` | `0x00000000` |
| 4 | `0x00000001` | 0 | `0x00000000` | `0x21041001` | `0x00000000` |
| 5 | `0x00000001` | 0 | `0x00000000` | `0x21441001` | `0x00000000` |
| 6 | `0x00000001` | 0 | `0x00000000` | `0x21841001` | `0x00000000` |
| 7 | `0x00000001` | 0 | `0x00000000` | `0x21C41001` | `0x00000000` |
