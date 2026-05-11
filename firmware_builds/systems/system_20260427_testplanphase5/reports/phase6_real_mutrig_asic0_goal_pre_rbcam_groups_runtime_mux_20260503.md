# Phase 6 ASIC0 Real MuTRiG ASIC0 Goal Pre-rbCAM Histogram Collection

- Timestamp: `2026-05-03T16:20:06`
- Result: `FAIL`
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
| `rate` | `10k` | 70040 | 3449997 | 17 | -64.0 | 58.721326 | 41.278674 | 0.000000 | 4292687356/0 | 124425.828660/0.000000 | 0 | 4294333852/4294332300/4294333152/4294824620 | 312002788/311999236 | 37107871.24/37107448.78 | 4294332300/4294333152/4294332624 | 510744031.10/510743968.30 | 4294334296/4294333532 | 0/0 | 0/0 | 0/0 | 8.408 | `phase6_real_mutrig_asic0_goal_pre_rbcam_rate_10k_delay_hit_t_runtime_mux_20260503.csv` |
| `rate` | `100k` | 70041 | 4535453 | 17 | -80.0 | 53.430297 | 46.569703 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 312052868/312050560 | 37177902.20/37177627.23 | 0/0/0 | 0.00/0.00 | 0/0 | 0/0 | 0/0 | 0/0 | 8.394 | `phase6_real_mutrig_asic0_goal_pre_rbcam_rate_100k_delay_hit_t_runtime_mux_20260503.csv` |
| `rate` | `500k` | 70042 | 4126786 | 17 | -64.0 | 58.720806 | 41.279194 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 311786924/311787880 | 37078674.82/37078788.51 | 0/0/0 | 0.00/0.00 | 0/0 | 0/0 | 0/0 | 0/0 | 8.409 | `phase6_real_mutrig_asic0_goal_pre_rbcam_rate_500k_delay_hit_t_runtime_mux_20260503.csv` |
| `rate` | `1M` | 70043 | 4267996 | 17 | -64.0 | 50.525024 | 49.474976 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 312423063/312428396 | 37203883.07/37204518.13 | 0/0/0 | 0.00/0.00 | 0/0 | 0/0 | 0/0 | 0/0 | 8.398 | `phase6_real_mutrig_asic0_goal_pre_rbcam_rate_1M_delay_hit_t_runtime_mux_20260503.csv` |
| `header_multiplicity` | `mult2` | 70044 | 0 | 0 | None | 0.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 0/0 | 0.00/0.00 | 0/0/0 | 0.00/0.00 | 0/0 | 0/0 | 0/0 | 0/0 | 8.439 | `phase6_real_mutrig_asic0_goal_pre_rbcam_header_mult2_delay_hit_t_runtime_mux_20260503.csv` |
| `header_multiplicity` | `mult3` | 70045 | 3856132 | 17 | -64.0 | 59.497730 | 40.502270 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 311720588/311721636 | 37117930.84/37118055.63 | 0/0/0 | 0.00/0.00 | 0/0 | 0/0 | 0/0 | 0/0 | 8.398 | `phase6_real_mutrig_asic0_goal_pre_rbcam_header_mult3_delay_hit_t_runtime_mux_20260503.csv` |
| `header_multiplicity` | `mult4` | 70046 | 4800862 | 17 | -64.0 | 53.294658 | 46.705342 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 311529684/311534153 | 37117573.99/37118106.45 | 0/0/0 | 0.00/0.00 | 0/0 | 0/0 | 0/0 | 0/0 | 8.393 | `phase6_real_mutrig_asic0_goal_pre_rbcam_header_mult4_delay_hit_t_runtime_mux_20260503.csv` |
| `header_multiplicity` | `mult5` | 70047 | 0 | 0 | None | 0.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 0/0 | 0.00/0.00 | 0/0/0 | 0.00/0.00 | 0/0 | 0/0 | 0/0 | 0/0 | 8.389 | `phase6_real_mutrig_asic0_goal_pre_rbcam_header_mult5_delay_hit_t_runtime_mux_20260503.csv` |
