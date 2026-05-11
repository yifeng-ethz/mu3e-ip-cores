# Phase 6 ASIC0 Real MuTRiG ASIC0 CML restore skip-reset Pre-rbCAM Histogram Collection

- Timestamp: `2026-05-04T00:02:58`
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
| `rate` | `10k` | 72310 | 319968 | 17 | -32.0 | 53.108436 | 46.891564 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 9638720/9638656 | 1192396.06/1192388.14 | 2404951/1808251/1808251 | 223696.86/223696.86 | 3448/1804726 | 0/0 | 0/0 | 0/0 | 8.083 | `phase6_goal_skipreset_asic0_pre_rbcam_rate_10k_delay_hit_t_runtime_mux_20260503.csv` |
| `rate` | `100k` | 72311 | 3010643 | 17 | -16.0 | 50.254447 | 49.745553 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 96310080/96308987 | 11896569.52/11896434.51 | 0/24075297/24075297 | 2973867.79/2973867.79 | 46227/24029264 | 0/0 | 0/0 | 0/0 | 8.096 | `phase6_goal_skipreset_asic0_pre_rbcam_rate_100k_delay_hit_t_runtime_mux_20260503.csv` |
| `rate` | `500k` | 72312 | 9010117 | 17 | 80.0 | 47.953206 | 52.046794 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 478249422/478247469 | 59121466.11/59121224.68 | 0/119563250/119563465 | 14780477.11/14780503.68 | 232401/119519639 | 0/0 | 0/0 | 0/0 | 8.089 | `phase6_goal_skipreset_asic0_pre_rbcam_rate_500k_delay_hit_t_runtime_mux_20260503.csv` |
| `rate` | `1M` | 72313 | 4199287 | 17 | -16.0 | 30.444097 | 69.555903 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 950122924/950110932 | 117168153.41/117166674.57 | 0/78973500/78973539 | 9738928.44/9738933.25 | 152753/78932649 | 0/0 | 0/0 | 0/0 | 8.109 | `phase6_goal_skipreset_asic0_pre_rbcam_rate_1M_delay_hit_t_runtime_mux_20260503.csv` |
| `header_multiplicity` | `mult2` | 72314 | 5236228 | 17 | 80.0 | 64.976582 | 35.023418 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 264923743/264098855 | 32657037.10/32555353.51 | 0/65673265/65673288 | 8095515.44/8095518.27 | 126546/65605268 | 0/0 | 0/0 | 0/0 | 8.112 | `phase6_goal_skipreset_asic0_pre_rbcam_header_mult2_delay_hit_t_runtime_mux_20260503.csv` |
| `header_multiplicity` | `mult3` | 72315 | 4963100 | 17 | 32.0 | 62.268562 | 37.731438 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 395383113/391182119 | 48724271.82/48206570.47 | 959073/96920133/96920002 | 11943764.79/11943748.65 | 183055/96749321 | 0/0 | 0/0 | 0/0 | 8.115 | `phase6_goal_skipreset_asic0_pre_rbcam_header_mult3_delay_hit_t_runtime_mux_20260503.csv` |
| `header_multiplicity` | `mult4` | 72316 | 9636291 | 17 | 16.0 | 63.850718 | 36.149282 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 525461120/521631065 | 64868722.51/64395898.23 | 704071/107366664/107363612 | 13254526.49/13254149.72 | 202424/107154226 | 0/0 | 0/0 | 0/0 | 8.100 | `phase6_goal_skipreset_asic0_pre_rbcam_header_mult4_delay_hit_t_runtime_mux_20260503.csv` |
| `header_multiplicity` | `mult5` | 72317 | 9388101 | 17 | 16.0 | 46.931408 | 53.068592 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 660914544/654906395 | 81609884.15/80867996.49 | 619072/104489202/104488858 | 12902351.37/12902308.89 | 196664/104285013 | 0/0 | 0/0 | 0/0 | 8.098 | `phase6_goal_skipreset_asic0_pre_rbcam_header_mult5_delay_hit_t_runtime_mux_20260503.csv` |
