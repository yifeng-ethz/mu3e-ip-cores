# Phase 5 Injector Datapath Sanity Report

- Timestamp: `2026-04-29T10:12:55`
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
| 0 | 47100 | `mixed` | `periodic` | 12500 | 31475 | 0 | 23875 | 0 | 4464421659 | 4464421659 | `PASS` |
| 1 | 47101 | `mixed` | `periodic` | 12500 | 31559 | 0 | 24243 | 0 | 3375762581 | 3375762581 | `PASS` |
| 2 | 47102 | `mixed` | `periodic` | 12500 | 29939 | 0 | 24703 | 0 | 3277972429 | 3277972429 | `PASS` |
| 3 | 47103 | `mixed` | `periodic` | 12500 | 30818 | 0 | 24002 | 0 | 3167600796 | 3167600796 | `PASS` |
| 4 | 47104 | `mixed` | `periodic` | 12500 | 32764 | 0 | 25291 | 0 | 3315492584 | 3315492584 | `PASS` |
| 5 | 47105 | `mixed` | `periodic` | 12500 | 29251 | 0 | 24108 | 0 | 3204994470 | 3204994470 | `PASS` |
| 6 | 47106 | `mixed` | `periodic` | 12500 | 33295 | 0 | 25884 | 0 | 3346941233 | 3346941233 | `PASS` |
| 7 | 47107 | `mixed` | `periodic` | 12500 | 32062 | 0 | 24894 | 0 | 3322445885 | 3322445885 | `PASS` |
| 8 | 47108 | `mixed` | `periodic` | 12500 | 31649 | 0 | 25310 | 0 | 3303719029 | 3303719029 | `PASS` |
| 9 | 47109 | `mixed` | `periodic` | 12500 | 30447 | 0 | 25721 | 0 | 3219483874 | 3219483874 | `PASS` |
| 10 | 47110 | `mixed` | `periodic` | 12500 | 31626 | 0 | 24492 | 0 | 3341159537 | 3341159537 | `PASS` |
| 11 | 47111 | `mixed` | `periodic` | 12500 | 29716 | 0 | 24567 | 0 | 3257538786 | 3257538786 | `PASS` |

## Configuration Notes

- The active `mutrig_injector_0` exposes one `coe_inject_pulse` output. The emulator `inject_channel_mask` CSR is still written for visibility, but that mask only affects the separate masked-trigger conduit and is not driven by this injector instance.
- Channel sanity in this report is therefore represented by emulator cluster center/size; ASIC sanity is represented by `active_lanes_mask` and the per-lane source mux selection.
- The runner writes injector mode `0` before setup and immediately after the injection window because the current injector RTL accepts run-control but does not gate the pulse arbiter by RUNNING.

## Per-Case Details

### Case 0

- Run number: `47100`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000403`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `4464421659`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `30205`
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

- Run number: `47101`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3375762581`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `30199`
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

- Run number: `47102`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3277972429`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `30657`
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

- Run number: `47103`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3167600796`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `30451`
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

- Run number: `47104`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3315492584`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `31618`
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

- Run number: `47105`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3204994470`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `29856`
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

- Run number: `47106`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3346941233`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `32061`
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

- Run number: `47107`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3322445885`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `30893`
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

- Run number: `47108`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3303719029`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `31109`
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

- Run number: `47109`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3219483874`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `31732`
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

- Run number: `47110`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3341159537`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `30507`
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

- Run number: `47111`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3257538786`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `30588`
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
