# Phase 6 ASIC0 Real MuTRiG ASIC0 CML restore Pre-rbCAM Histogram Collection

- Timestamp: `2026-05-03T23:53:45`
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
| `rate` | `10k` | 72200 | 319968 | 17 | 80.0 | 53.158753 | 46.841247 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 9652352/9652352 | 1188781.72/1188781.72 | 2408400/1810852/1810804 | 223024.17/223018.26 | 3462/1807323 | 0/0 | 0/0 | 0/0 | 8.120 | `phase6_goal_cmlrestore_asic0_pre_rbcam_rate_10k_delay_hit_t_runtime_mux_20260503.csv` |
| `rate` | `100k` | 72201 | 3194880 | 17 | -96.0 | 53.123091 | 46.876909 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 96266911/96267008 | 11860825.14/11860837.09 | 0/24064835/24064836 | 2964973.08/2964973.21 | 45960/24018160 | 0/0 | 0/0 | 0/0 | 8.116 | `phase6_goal_cmlrestore_asic0_pre_rbcam_rate_100k_delay_hit_t_runtime_mux_20260503.csv` |
| `rate` | `500k` | 72202 | 10835508 | 17 | -32.0 | 52.491604 | 47.508396 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 479402316/479399104 | 59131444.00/59131047.81 | 0/119853212/119853299 | 14783185.76/14783196.49 | 233116/119819662 | 0/0 | 0/0 | 0/0 | 8.107 | `phase6_goal_cmlrestore_asic0_pre_rbcam_rate_500k_delay_hit_t_runtime_mux_20260503.csv` |
| `rate` | `1M` | 72203 | 2380312 | 17 | 80.0 | 53.827271 | 46.172729 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 951725647/951744910 | 117138886.05/117141256.95 | 0/79112783/79112669 | 9737242.35/9737228.32 | 153041/79071695 | 0/0 | 0/0 | 0/0 | 8.125 | `phase6_goal_cmlrestore_asic0_pre_rbcam_rate_1M_delay_hit_t_runtime_mux_20260503.csv` |
| `header_multiplicity` | `mult2` | 72204 | 5751181 | 17 | -64.0 | 54.789981 | 45.210019 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 265204168/264516319 | 32820377.30/32735252.46 | 0/65718975/65718958 | 8133060.55/8133058.44 | 126631/65650961 | 0/0 | 0/0 | 0/0 | 8.080 | `phase6_goal_cmlrestore_asic0_pre_rbcam_header_mult2_delay_hit_t_runtime_mux_20260503.csv` |
| `header_multiplicity` | `mult3` | 72205 | 10650639 | 17 | 48.0 | 57.133999 | 42.866001 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 394920895/391244397 | 48839407.92/48384739.69 | 998821/96752368/96752454 | 11965252.86/11965263.49 | 182803/96581738 | 0/0 | 0/0 | 0/0 | 8.086 | `phase6_goal_cmlrestore_asic0_pre_rbcam_header_mult3_delay_hit_t_runtime_mux_20260503.csv` |
| `header_multiplicity` | `mult4` | 72206 | 6784728 | 17 | -112.0 | 34.560766 | 65.439234 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 525857971/522106342 | 64832791.41/64370254.76 | 825061/107375791/107372095 | 13238312.71/13237857.03 | 202000/107164500 | 0/0 | 0/0 | 0/0 | 8.111 | `phase6_goal_cmlrestore_asic0_pre_rbcam_header_mult4_delay_hit_t_runtime_mux_20260503.csv` |
| `header_multiplicity` | `mult5` | 72207 | 8801978 | 17 | 32.0 | 80.036249 | 19.963751 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 659922666/654571657 | 81545266.22/80884053.21 | 708410/104383524/104383184 | 12898454.16/12898412.14 | 196281/104179599 | 0/0 | 0/0 | 0/0 | 8.093 | `phase6_goal_cmlrestore_asic0_pre_rbcam_header_mult5_delay_hit_t_runtime_mux_20260503.csv` |
