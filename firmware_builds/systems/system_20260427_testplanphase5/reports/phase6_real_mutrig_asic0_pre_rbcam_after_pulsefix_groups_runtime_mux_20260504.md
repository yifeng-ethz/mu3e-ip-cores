# Phase 6 ASIC0 Real MuTRiG Pre-rbCAM Histogram Collection

- Timestamp: `2026-05-04T04:55:59`
- Result: `FAIL`
- Active lane: `0`
- Source mux: `skipped / absent in this image`
- Emulator trigger mode: `external-injector`
- Emulator CSR setup: `skipped`
- Histogram selector: `hit-processor ingress at 0x0AB00`
- Histogram profile: `delay-hit-t-pre`
- Delay window: `[0, 2000)` cycles
- Header delay: `500` cycles
- Pulse high: `5` cycles

| Group | Case | Run | Hits | Nonzero | Peak [cyc] | In % | Low Out % | High Out % | Hist UF/OF | Hist UF/OF % | Hist Drops | Selector HP/RB/Emit/Drop | MTS0/1 Hits | MTS0/1 Hz | rbCAM InErr/Push/Pop | rbCAM Push/Pop Hz | rbCAM Overwrite/Miss | Source R/E In | Source R/E Out | Source R/E Drop | Window s | CSV |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `rate` | `10k` | 68100 | 0 | 0 | None | 0.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 0/0 | 0.00/0.00 | 0/0/0 | 0.00/0.00 | 0/0 | 0/0 | 0/0 | 0/0 | 8.110 | `phase6_real_mutrig_asic0_pre_rbcam_after_pulsefix_rate_10k_delay_hit_t_runtime_mux_20260504.csv` |
| `rate` | `100k` | 68101 | 0 | 0 | None | 0.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 0/0 | 0.00/0.00 | 0/0/0 | 0.00/0.00 | 0/0 | 0/0 | 0/0 | 0/0 | 8.073 | `phase6_real_mutrig_asic0_pre_rbcam_after_pulsefix_rate_100k_delay_hit_t_runtime_mux_20260504.csv` |
| `rate` | `500k` | 68102 | 0 | 0 | None | 0.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 0/0 | 0.00/0.00 | 0/0/0 | 0.00/0.00 | 0/0 | 0/0 | 0/0 | 0/0 | 8.111 | `phase6_real_mutrig_asic0_pre_rbcam_after_pulsefix_rate_500k_delay_hit_t_runtime_mux_20260504.csv` |
| `rate` | `1M` | 68103 | 0 | 0 | None | 0.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 0/0 | 0.00/0.00 | 0/0/0 | 0.00/0.00 | 0/0 | 0/0 | 0/0 | 0/0 | 8.091 | `phase6_real_mutrig_asic0_pre_rbcam_after_pulsefix_rate_1M_delay_hit_t_runtime_mux_20260504.csv` |
