# Phase 6 ASIC0 emulator_internal_debug Pre-rbCAM Histogram Collection

- Timestamp: `2026-05-03T14:49:40`
- Result: `PASS`
- Active lane: `0`
- Source mux: `all lanes forced to emulator`
- Emulator trigger mode: `internal-periodic`
- Emulator CSR setup: `enabled for active lane`
- Histogram selector: `hit-processor ingress at 0x0AB00`
- Histogram profile: `delay-hit-t-pre`
- Delay window: `[0, 2000)` cycles
- Header delay: `500` cycles
- Pulse high: `5` cycles

| Group | Case | Run | Hits | Nonzero | Peak [cyc] | In % | Low Out % | High Out % | Hist UF/OF | Hist UF/OF % | Hist Drops | Selector HP/RB/Emit/Drop | MTS0/1 Hits | MTS0/1 Hz | rbCAM InErr/Push/Pop | rbCAM Push/Pop Hz | rbCAM Overwrite/Miss | Source R/E In | Source R/E Out | Source R/E Drop | Window s | CSV |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `rate` | `10k` | 70210 | 19074 | 98 | 80.0 | 100.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 167912/17227617/167912/0 | 162642/0 | 19344.29/0.00 | 0/33982/33980 | 4041.75/4041.51 | 0/33913 | 0/0 | 0/0 | 172060/0 | 8.408 | `phase6_emulator_internal_debug_pre_rate_10k_delay_hit_t_runtime_mux_20260503.csv` |
| `rate` | `100k` | 70211 | 198364 | 98 | 320.0 | 100.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 1746978/17604155/1746978/0 | 1690870/0 | 201303.45/0.00 | 0/408140/408142 | 48590.36/48590.60 | 0/407344 | 0/0 | 0/0 | 1790764/0 | 8.400 | `phase6_emulator_internal_debug_pre_rate_100k_delay_hit_t_runtime_mux_20260503.csv` |
| `rate` | `500k` | 70212 | 999450 | 94 | 144.0 | 100.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 8780686/19304087/8780686/0 | 8510378/0 | 1012468.43/0.00 | 0/2174403/2174405 | 258685.85/258686.09 | 0/2170157 | 0/0 | 0/0 | 9013926/0 | 8.406 | `phase6_emulator_internal_debug_pre_rate_500k_delay_hit_t_runtime_mux_20260503.csv` |
| `rate` | `1M` | 70213 | 1998898 | 89 | 1008.0 | 100.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 17589541/21483410/17589536/0 | 17012611/0 | 2026764.19/0.00 | 0/4349732/4349730 | 518196.83/518196.59 | 0/4341235 | 0/0 | 0/0 | 18036228/0 | 8.394 | `phase6_emulator_internal_debug_pre_rate_1M_delay_hit_t_runtime_mux_20260503.csv` |
