# Phase 6 ASIC0 Real MuTRiG ASIC0 debug1 pre Pre-rbCAM Histogram Collection

- Timestamp: `2026-05-04T01:06:03`
- Result: `PASS`
- Active lane: `0`
- Source mux: `all lanes forced to real`
- Emulator trigger mode: `external-injector`
- Emulator CSR setup: `skipped`
- Histogram selector: `hit-processor ingress at 0x0AB00`
- Histogram profile: `delay-debug1`
- Delay window: `[0, 2000)` cycles
- Header delay: `500` cycles
- Pulse high: `5` cycles

| Group | Case | Run | Hits | Nonzero | Peak [cyc] | In % | Low Out % | High Out % | Hist UF/OF | Hist UF/OF % | Hist Drops | Selector HP/RB/Emit/Drop | MTS0/1 Hits | MTS0/1 Hz | rbCAM InErr/Push/Pop | rbCAM Push/Pop Hz | rbCAM Overwrite/Miss | Source R/E In | Source R/E Out | Source R/E Drop | Window s | CSV |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `rate` | `10k` | 77610 | 639785 | 164 | 0.0 | 99.961393 | 0.038607 | 0.000000 | 31/0 | 0.004845/0.000000 | 0 | 0/0/0/0 | 9856512/9856512 | 1171625.11/1171625.11 | 0/2464183/2464183 | 292912.82/292912.82 | 4801/2459381 | 0/0 | 0/0 | 0/0 | 8.413 | `phase6_goal_debug1_asic0_pre_rbcam_rate_10k_delay_hit_t_runtime_mux_20260504.csv` |
| `rate` | `100k` | 77611 | 6388773 | 186 | 0.0 | 99.985130 | 0.014557 | 0.000313 | 4294966712/0 | 67226.785362/0.000000 | 0 | 0/0/0/0 | 98330944/98331456 | 11716206.92/11716267.92 | 0/24582873/24582873 | 2929068.05/2929068.05 | 47430/24535122 | 0/0 | 0/0 | 0/0 | 8.393 | `phase6_goal_debug1_asic0_pre_rbcam_rate_100k_delay_hit_t_runtime_mux_20260504.csv` |
| `rate` | `500k` | 77612 | 5129217 | 190 | 0.0 | 99.899341 | 0.095707 | 0.004952 | 4294964410/0 | 83735.283767/0.000000 | 0 | 0/0/0/0 | 488222016/488226612 | 58149521.08/58150068.48 | 0/122056227/122055883 | 14537466.38/14537425.41 | 235466/121996689 | 0/0 | 0/0 | 0/0 | 8.396 | `phase6_goal_debug1_asic0_pre_rbcam_rate_500k_delay_hit_t_runtime_mux_20260504.csv` |
| `rate` | `1M` | 77613 | 9425494 | 191 | 0.0 | 99.955748 | 0.041802 | 0.002451 | 4294960218/0 | 45567.481322/0.000000 | 0 | 0/0/0/0 | 966998441/966986688 | 115354918.22/115353516.18 | 0/80393271/80393046 | 9590252.48/9590225.64 | 155544/80351499 | 0/0 | 0/0 | 0/0 | 8.383 | `phase6_goal_debug1_asic0_pre_rbcam_rate_1M_delay_hit_t_runtime_mux_20260504.csv` |
