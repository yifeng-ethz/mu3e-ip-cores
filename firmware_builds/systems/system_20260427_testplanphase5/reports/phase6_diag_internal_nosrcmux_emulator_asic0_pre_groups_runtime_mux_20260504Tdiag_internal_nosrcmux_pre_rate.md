# Phase 6 ASIC0 Emulator Internal No SourceMux Pre-rbCAM Histogram Collection

- Timestamp: `2026-05-04T02:33:15`
- Result: `FAIL`
- Active lane: `0`
- Source mux: `skipped / absent in this image`
- Emulator trigger mode: `internal-periodic`
- Emulator CSR setup: `enabled for active lane`
- Histogram selector: `hit-processor ingress at 0x0AB00`
- Histogram profile: `delay-hit-t-pre`
- Delay window: `[0, 2000)` cycles
- Header delay: `500` cycles
- Pulse high: `5` cycles

| Group | Case | Run | Hits | Nonzero | Peak [cyc] | In % | Low Out % | High Out % | Hist UF/OF | Hist UF/OF % | Hist Drops | Selector HP/RB/Emit/Drop | MTS0/1 Hits | MTS0/1 Hz | rbCAM InErr/Push/Pop | rbCAM Push/Pop Hz | rbCAM Overwrite/Miss | Source R/E In | Source R/E Out | Source R/E Drop | Window s | CSV |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `rate` | `10k` | 70300 | 0 | 0 | None | 0.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 0/0 | 0.00/0.00 | 0/0/0 | 0.00/0.00 | 0/0 | 0/0 | 0/0 | 0/0 | 8.387 | `phase6_diag_internal_nosrcmux_emulator_asic0_pre_rate_10k_delay_hit_t_runtime_mux_20260504Tdiag_internal_nosrcmux_pre_rate.csv` |
| `rate` | `100k` | 70301 | 0 | 0 | None | 0.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 0/0 | 0.00/0.00 | 0/0/0 | 0.00/0.00 | 0/0 | 0/0 | 0/0 | 0/0 | 8.408 | `phase6_diag_internal_nosrcmux_emulator_asic0_pre_rate_100k_delay_hit_t_runtime_mux_20260504Tdiag_internal_nosrcmux_pre_rate.csv` |
| `rate` | `500k` | 70302 | 0 | 0 | None | 0.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 0/0 | 0.00/0.00 | 0/0/0 | 0.00/0.00 | 0/0 | 0/0 | 0/0 | 0/0 | 8.372 | `phase6_diag_internal_nosrcmux_emulator_asic0_pre_rate_500k_delay_hit_t_runtime_mux_20260504Tdiag_internal_nosrcmux_pre_rate.csv` |
| `rate` | `1M` | 70303 | 0 | 0 | None | 0.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 0/0 | 0.00/0.00 | 0/0/0 | 0.00/0.00 | 0/0 | 0/0 | 0/0 | 0/0 | 8.419 | `phase6_diag_internal_nosrcmux_emulator_asic0_pre_rate_1M_delay_hit_t_runtime_mux_20260504Tdiag_internal_nosrcmux_pre_rate.csv` |
