# Phase 6 ASIC0 emulator_debug Pre-rbCAM Histogram Collection

- Timestamp: `2026-05-03T14:48:28`
- Result: `FAIL`
- Active lane: `0`
- Source mux: `all lanes forced to emulator`
- Emulator trigger mode: `external-injector`
- Emulator CSR setup: `enabled for active lane`
- Histogram selector: `hit-processor ingress at 0x0AB00`
- Histogram profile: `delay-hit-t-pre`
- Delay window: `[0, 2000)` cycles
- Header delay: `500` cycles
- Pulse high: `5` cycles

| Group | Case | Run | Hits | Nonzero | Peak [cyc] | In % | Low Out % | High Out % | Hist UF/OF | Hist UF/OF % | Hist Drops | Selector HP/RB/Emit/Drop | MTS0/1 Hits | MTS0/1 Hz | rbCAM InErr/Push/Pop | rbCAM Push/Pop Hz | rbCAM Overwrite/Miss | Source R/E In | Source R/E Out | Source R/E Drop | Window s | CSV |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `rate` | `10k` | 70200 | 0 | 0 | None | 0.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/17178105/0/0 | 0/0 | 0.00/0.00 | 0/0/0 | 0.00/0.00 | 0/0 | 0/0 | 0/0 | 0/0 | 8.392 | `phase6_emulator_debug_pre_rate_10k_delay_hit_t_runtime_mux_20260503.csv` |
| `rate` | `100k` | 70201 | 0 | 0 | None | 0.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/17127386/0/0 | 0/0 | 0.00/0.00 | 0/0/0 | 0.00/0.00 | 0/0 | 0/0 | 0/0 | 0/0 | 8.375 | `phase6_emulator_debug_pre_rate_100k_delay_hit_t_runtime_mux_20260503.csv` |
| `rate` | `500k` | 70202 | 0 | 0 | None | 0.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/17131972/0/0 | 0/0 | 0.00/0.00 | 0/0/0 | 0.00/0.00 | 0/0 | 0/0 | 0/0 | 0/0 | 8.378 | `phase6_emulator_debug_pre_rate_500k_delay_hit_t_runtime_mux_20260503.csv` |
| `rate` | `1M` | 70203 | 0 | 0 | None | 0.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/17156043/0/0 | 0/0 | 0.00/0.00 | 0/0/0 | 0.00/0.00 | 0/0 | 0/0 | 0/0 | 0/0 | 8.395 | `phase6_emulator_debug_pre_rate_1M_delay_hit_t_runtime_mux_20260503.csv` |
