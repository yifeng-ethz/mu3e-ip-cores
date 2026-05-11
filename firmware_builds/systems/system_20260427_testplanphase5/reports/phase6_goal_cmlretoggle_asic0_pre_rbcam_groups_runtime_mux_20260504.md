# Phase 6 ASIC0 Real MuTRiG ASIC0 CML retoggle pre Pre-rbCAM Histogram Collection

- Timestamp: `2026-05-04T00:49:06`
- Result: `PASS`
- Active lane: `0`
- Source mux: `all lanes forced to real`
- Emulator trigger mode: `external-injector`
- Emulator CSR setup: `skipped`
- Histogram selector: `hit-processor ingress at 0x0AB00`
- Histogram profile: `delay-hit-t-pre`
- Delay window: `[0, 2000)` cycles
- Header delay: `500` cycles
- Pulse high: `5` cycles

| Group | Case | Run | Hits | Nonzero | Peak [cyc] | In % | Low Out % | High Out % | Hist UF/OF | Hist UF/OF % | Hist Drops | Selector HP/RB/Emit/Drop | MTS0/1 Hits | MTS0/1 Hz | rbCAM InErr/Push/Pop | rbCAM Push/Pop Hz | rbCAM Overwrite/Miss | Source R/E In | Source R/E Out | Source R/E Drop | Window s | CSV |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `rate` | `10k` | 77200 | 319936 | 17 | -80.0 | 53.140628 | 46.859372 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 9847872/9848128 | 1172267.84/1172298.31 | 0/2461971/2461971 | 293067.32/293067.32 | 4788/2457180 | 0/0 | 0/0 | 0/0 | 8.401 | `phase6_goal_cmlretoggle_asic0_pre_rbcam_rate_10k_delay_hit_t_runtime_mux_20260504.csv` |
| `rate` | `100k` | 77201 | 3194848 | 17 | -112.0 | 53.121526 | 46.878474 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 98134592/98136418 | 11678787.86/11679005.17 | 0/24532835/24532899 | 2919600.21/2919607.83 | 47219/24485478 | 0/0 | 0/0 | 0/0 | 8.403 | `phase6_goal_cmlretoggle_asic0_pre_rbcam_rate_100k_delay_hit_t_runtime_mux_20260504.csv` |
| `rate` | `500k` | 77202 | 9986160 | 17 | -48.0 | 59.394202 | 40.605798 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 487924544/487910912 | 58138681.26/58137056.93 | 0/121983254/121983188 | 14534922.68/14534914.82 | 235128/121906619 | 0/0 | 0/0 | 0/0 | 8.392 | `phase6_goal_cmlretoggle_asic0_pre_rbcam_rate_500k_delay_hit_t_runtime_mux_20260504.csv` |
| `rate` | `1M` | 77203 | 8991304 | 17 | -16.0 | 29.220500 | 70.779500 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 966937763/966941773 | 115553138.42/115553617.64 | 0/80361800/80362094 | 9603573.83/9603608.97 | 155387/80319458 | 0/0 | 0/0 | 0/0 | 8.368 | `phase6_goal_cmlretoggle_asic0_pre_rbcam_rate_1M_delay_hit_t_runtime_mux_20260504.csv` |
