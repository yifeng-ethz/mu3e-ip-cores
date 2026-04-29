# Phase 5 Injector Datapath Sanity Report

- Timestamp: `2026-04-29T10:49:39`
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
- Result: `FAIL`

## Case Summary

| Case | Run | Source | Mode | Interval | Hist Hits | Hist Drops | MTS Hits | Ring InErr | Real Beats | Emu Beats | Class |
|---:|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | 47300 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3293486600 | 3293486600 | `blocked_before_emulator` |
| 1 | 47301 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3287209426 | 3287209426 | `blocked_before_emulator` |
| 2 | 47302 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3290594437 | 3290594437 | `blocked_before_emulator` |
| 3 | 47303 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3221673465 | 3221673465 | `blocked_before_emulator` |
| 4 | 47304 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3359855371 | 3359855371 | `blocked_before_emulator` |
| 5 | 47305 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3207093288 | 3207093288 | `blocked_before_emulator` |
| 6 | 47306 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3228247225 | 3228247225 | `blocked_before_emulator` |
| 7 | 47307 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3324735456 | 3324735456 | `blocked_before_emulator` |
| 8 | 47308 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3189382715 | 3189382715 | `blocked_before_emulator` |
| 9 | 47309 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3209900282 | 3209900282 | `blocked_before_emulator` |
| 10 | 47310 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3347813175 | 3347813175 | `blocked_before_emulator` |
| 11 | 47311 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3324367312 | 3324367312 | `blocked_before_emulator` |
| 12 | 47312 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3225214478 | 3225214478 | `blocked_before_emulator` |
| 13 | 47313 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3278418191 | 3278418191 | `blocked_before_emulator` |
| 14 | 47314 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3201645977 | 3201645977 | `blocked_before_emulator` |
| 15 | 47315 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3297370774 | 3297370774 | `blocked_before_emulator` |
| 16 | 47316 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3270221295 | 3270221295 | `blocked_before_emulator` |
| 17 | 47317 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3364315772 | 3364315772 | `blocked_before_emulator` |
| 18 | 47318 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 4472769634 | 4472769634 | `blocked_before_emulator` |
| 19 | 47319 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3200602516 | 3200602516 | `blocked_before_emulator` |
| 20 | 47320 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3317284928 | 3317284928 | `blocked_before_emulator` |
| 21 | 47321 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3261460438 | 3261460438 | `blocked_before_emulator` |
| 22 | 47322 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3257114589 | 3257114589 | `blocked_before_emulator` |
| 23 | 47323 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3283586736 | 3283586736 | `blocked_before_emulator` |
| 24 | 47324 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3289415229 | 3289415229 | `blocked_before_emulator` |
| 25 | 47325 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3384691906 | 3384691906 | `blocked_before_emulator` |
| 26 | 47326 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 4272509173 | 4272509173 | `blocked_before_emulator` |
| 27 | 47327 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3227709165 | 3227709165 | `blocked_before_emulator` |
| 28 | 47328 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3311802181 | 3311802181 | `blocked_before_emulator` |
| 29 | 47329 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3227464394 | 3227464394 | `blocked_before_emulator` |
| 30 | 47330 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 4396587513 | 4396587513 | `blocked_before_emulator` |
| 31 | 47331 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3218555347 | 3218555347 | `blocked_before_emulator` |
| 32 | 47332 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3219792852 | 3219792852 | `blocked_before_emulator` |
| 33 | 47333 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3355892268 | 3355892268 | `blocked_before_emulator` |
| 34 | 47334 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3301492070 | 3301492070 | `blocked_before_emulator` |
| 35 | 47335 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3140405786 | 3140405786 | `blocked_before_emulator` |
| 36 | 47336 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3280151954 | 3280151954 | `blocked_before_emulator` |
| 37 | 47337 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3333866809 | 3333866809 | `blocked_before_emulator` |
| 38 | 47338 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3266570672 | 3266570672 | `blocked_before_emulator` |
| 39 | 47339 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3378246705 | 3378246705 | `blocked_before_emulator` |
| 40 | 47340 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 4435742664 | 4435742664 | `blocked_before_emulator` |
| 41 | 47341 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3210003598 | 3210003598 | `blocked_before_emulator` |
| 42 | 47342 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3208976095 | 3208976095 | `blocked_before_emulator` |
| 43 | 47343 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3196343029 | 3196343029 | `blocked_before_emulator` |
| 44 | 47344 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3321142459 | 3321142459 | `blocked_before_emulator` |
| 45 | 47345 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3312876173 | 3312876173 | `blocked_before_emulator` |
| 46 | 47346 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3226667102 | 3226667102 | `blocked_before_emulator` |
| 47 | 47347 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3251723299 | 3251723299 | `blocked_before_emulator` |
| 48 | 47348 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3339398237 | 3339398237 | `blocked_before_emulator` |
| 49 | 47349 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3212500018 | 3212500018 | `blocked_before_emulator` |
| 50 | 47350 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3357186335 | 3357186335 | `blocked_before_emulator` |
| 51 | 47351 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3374367346 | 3374367346 | `blocked_before_emulator` |
| 52 | 47352 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3290654053 | 3290654053 | `blocked_before_emulator` |
| 53 | 47353 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3314583688 | 3314583688 | `blocked_before_emulator` |
| 54 | 47354 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3214170244 | 3214170244 | `blocked_before_emulator` |
| 55 | 47355 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3242326455 | 3242326455 | `blocked_before_emulator` |
| 56 | 47356 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3204161031 | 3204161031 | `blocked_before_emulator` |
| 57 | 47357 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3391987785 | 3391987785 | `blocked_before_emulator` |
| 58 | 47358 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3275797321 | 3275797321 | `blocked_before_emulator` |
| 59 | 47359 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3349471567 | 3349471567 | `blocked_before_emulator` |
| 60 | 47360 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3398282460 | 3398282460 | `blocked_before_emulator` |
| 61 | 47361 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3248156820 | 3248156820 | `blocked_before_emulator` |
| 62 | 47362 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3228852253 | 3228852253 | `blocked_before_emulator` |
| 63 | 47363 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3294154620 | 3294154620 | `blocked_before_emulator` |
| 64 | 47364 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3253081328 | 3253081328 | `blocked_before_emulator` |
| 65 | 47365 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3165121960 | 3165121960 | `blocked_before_emulator` |
| 66 | 47366 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3311960080 | 3311960080 | `blocked_before_emulator` |
| 67 | 47367 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3234537498 | 3234537498 | `blocked_before_emulator` |
| 68 | 47368 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3194221268 | 3194221268 | `blocked_before_emulator` |
| 69 | 47369 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3394159907 | 3394159907 | `blocked_before_emulator` |
| 70 | 47370 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3266036007 | 3266036007 | `blocked_before_emulator` |
| 71 | 47371 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3120897128 | 3120897128 | `blocked_before_emulator` |
| 72 | 47372 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3266871702 | 3266871702 | `blocked_before_emulator` |
| 73 | 47373 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3290310182 | 3290310182 | `blocked_before_emulator` |
| 74 | 47374 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3287658410 | 3287658410 | `blocked_before_emulator` |
| 75 | 47375 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3194345774 | 3194345774 | `blocked_before_emulator` |
| 76 | 47376 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3330128188 | 3330128188 | `blocked_before_emulator` |
| 77 | 47377 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3260602987 | 3260602987 | `blocked_before_emulator` |
| 78 | 47378 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3203390894 | 3203390894 | `blocked_before_emulator` |
| 79 | 47379 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3416254480 | 3416254480 | `blocked_before_emulator` |
| 80 | 47380 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3206264897 | 3206264897 | `blocked_before_emulator` |
| 81 | 47381 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3366554196 | 3366554196 | `blocked_before_emulator` |
| 82 | 47382 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3233893778 | 3233893778 | `blocked_before_emulator` |
| 83 | 47383 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3226758585 | 3226758585 | `blocked_before_emulator` |
| 84 | 47384 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3378335007 | 3378335007 | `blocked_before_emulator` |
| 85 | 47385 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3207801430 | 3207801430 | `blocked_before_emulator` |
| 86 | 47386 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3201277406 | 3201277406 | `blocked_before_emulator` |
| 87 | 47387 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3285300213 | 3285300213 | `blocked_before_emulator` |
| 88 | 47388 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3199539651 | 3199539651 | `blocked_before_emulator` |
| 89 | 47389 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3189761063 | 3189761063 | `blocked_before_emulator` |
| 90 | 47390 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3200918771 | 3200918771 | `blocked_before_emulator` |
| 91 | 47391 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3166862627 | 3166862627 | `blocked_before_emulator` |
| 92 | 47392 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3274502170 | 3274502170 | `blocked_before_emulator` |
| 93 | 47393 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3302232796 | 3302232796 | `blocked_before_emulator` |
| 94 | 47394 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3247474191 | 3247474191 | `blocked_before_emulator` |
| 95 | 47395 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3169642351 | 3169642351 | `blocked_before_emulator` |
| 96 | 47396 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3385115209 | 3385115209 | `blocked_before_emulator` |
| 97 | 47397 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3213044681 | 3213044681 | `blocked_before_emulator` |
| 98 | 47398 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3394982698 | 3394982698 | `blocked_before_emulator` |
| 99 | 47399 | `mixed` | `periodic` | 12500 | 0 | 0 | 0 | 0 | 3180896168 | 3180896168 | `blocked_before_emulator` |

## Configuration Notes

- The active `mutrig_injector_0` exposes one `coe_inject_pulse` output. The emulator `inject_channel_mask` CSR is still written for visibility, but that mask only affects the separate masked-trigger conduit and is not driven by this injector instance.
- Channel sanity in this report is therefore represented by emulator cluster center/size; ASIC sanity is represented by `active_lanes_mask` and the per-lane source mux selection.
- The runner writes injector mode `0` before setup and immediately after the injection window because the current injector RTL accepts run-control but does not gate the pulse arbiter by RUNNING.

## Per-Case Details

### Case 0

- Run number: `47300`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000403`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3293486600`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47301`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3287209426`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47302`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3290594437`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47303`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3221673465`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47304`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3359855371`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47305`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3207093288`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47306`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3228247225`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47307`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3324735456`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47308`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3189382715`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47309`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3209900282`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47310`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3347813175`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47311`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3324367312`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47312`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3225214478`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47313`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3278418191`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47314`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3201645977`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47315`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3297370774`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47316`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3270221295`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47317`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3364315772`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47318`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `4472769634`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47319`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3200602516`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47320`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3317284928`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47321`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3261460438`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47322`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3257114589`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47323`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3283586736`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47324`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3289415229`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47325`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3384691906`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47326`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `4272509173`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47327`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3227709165`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47328`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3311802181`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47329`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3227464394`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47330`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `4396587513`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47331`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3218555347`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47332`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3219792852`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47333`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3355892268`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47334`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3301492070`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47335`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3140405786`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47336`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3280151954`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47337`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3333866809`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47338`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3266570672`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

- Run number: `47339`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3378246705`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 40

- Run number: `47340`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `4435742664`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 41

- Run number: `47341`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3210003598`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 42

- Run number: `47342`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3208976095`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 43

- Run number: `47343`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3196343029`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 44

- Run number: `47344`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3321142459`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 45

- Run number: `47345`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3312876173`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 46

- Run number: `47346`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3226667102`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 47

- Run number: `47347`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3251723299`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 48

- Run number: `47348`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3339398237`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 49

- Run number: `47349`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3212500018`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 50

- Run number: `47350`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3357186335`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 51

- Run number: `47351`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3374367346`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 52

- Run number: `47352`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3290654053`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 53

- Run number: `47353`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3314583688`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 54

- Run number: `47354`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3214170244`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 55

- Run number: `47355`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3242326455`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 56

- Run number: `47356`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3204161031`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 57

- Run number: `47357`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3391987785`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 58

- Run number: `47358`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3275797321`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 59

- Run number: `47359`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3349471567`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 60

- Run number: `47360`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3398282460`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 61

- Run number: `47361`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3248156820`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 62

- Run number: `47362`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3228852253`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 63

- Run number: `47363`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3294154620`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 64

- Run number: `47364`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3253081328`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 65

- Run number: `47365`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3165121960`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 66

- Run number: `47366`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3311960080`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 67

- Run number: `47367`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3234537498`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 68

- Run number: `47368`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3194221268`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 69

- Run number: `47369`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3394159907`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 70

- Run number: `47370`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3266036007`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 71

- Run number: `47371`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3120897128`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 72

- Run number: `47372`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3266871702`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 73

- Run number: `47373`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3290310182`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 74

- Run number: `47374`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3287658410`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 75

- Run number: `47375`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000603`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3194345774`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 76

- Run number: `47376`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3330128188`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 77

- Run number: `47377`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000403`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3260602987`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 78

- Run number: `47378`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3203390894`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 79

- Run number: `47379`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3416254480`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 80

- Run number: `47380`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3206264897`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 81

- Run number: `47381`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3366554196`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 82

- Run number: `47382`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3233893778`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 83

- Run number: `47383`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3226758585`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 84

- Run number: `47384`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3378335007`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 85

- Run number: `47385`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000403`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3207801430`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 86

- Run number: `47386`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3201277406`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 87

- Run number: `47387`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3285300213`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 88

- Run number: `47388`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000603`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3199539651`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 89

- Run number: `47389`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3189761063`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 90

- Run number: `47390`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3200918771`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 91

- Run number: `47391`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3166862627`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 92

- Run number: `47392`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3274502170`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 93

- Run number: `47393`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3302232796`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 94

- Run number: `47394`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000603`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3247474191`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 95

- Run number: `47395`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3169642351`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 96

- Run number: `47396`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3385115209`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 97

- Run number: `47397`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3213044681`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 98

- Run number: `47398`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000E03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3394982698`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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

### Case 99

- Run number: `47399`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Injector mode during run: `2`
- Injector mode after run: `0`
- Lane-go readback: `0x00000009`
- Histogram ingress status: `0x00000C03`
- Debug overrides: `{'mts_expected_latency': None, 'mts_delay_ts_field': 'keep', 'mts_drop_delay_error': 'keep', 'ring_filter_inerr': 'keep'}`
- Source mux selected beat delta: `3180896168`
- Emulator frame delta: `0`
- Frame CRC delta: `0`
- Frame actual-hit delta: `0`
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
