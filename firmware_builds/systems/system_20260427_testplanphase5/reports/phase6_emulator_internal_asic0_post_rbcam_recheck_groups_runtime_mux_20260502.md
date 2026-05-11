# Phase 6 ASIC0 Emulator Internal Recheck Post-rbCAM Histogram Collection

- Timestamp: `2026-05-02T23:40:46`
- Result: `FAIL`
- Active lane: `0`
- Source mux: `all lanes forced to emulator`
- Emulator trigger mode: `internal-periodic`
- Emulator CSR setup: `enabled for active lane`
- Histogram selector: `filtered rbCAM egress at 0x0AB00`
- Header delay: `500` cycles
- Pulse high: `5` cycles

| Group | Case | Run | Hits | Nonzero | Peak [cyc] | In % | Low Out % | High Out % | Hist UF/OF | Hist UF/OF % | Hist Drops | Selector HP/RB/Emit/Drop | MTS0/1 Hits | MTS0/1 Hz | rbCAM InErr/Push/Pop | rbCAM Push/Pop Hz | rbCAM Overwrite/Miss | Source R/E In | Source R/E Out | Source R/E Drop | Window s | CSV |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `header_multiplicity` | `mult2` | 69300 | 0 | 0 | None | 0.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 0/0 | 0.00/0.00 | 0/0/0 | 0.00/0.00 | 0/0 | 0/0 | 0/0 | 0/0 | 8.405 | `phase6_emulator_internal_asic0_post_rbcam_recheck_header_mult2_delay_hit_t_runtime_mux_20260502.csv` |
| `header_multiplicity` | `mult3` | 69301 | 61056 | 13 | 208.0 | 100.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 4682400/936480/936480/0 | 4682400/0 | 558638.70/0.00 | 0/936480/936480 | 111727.74/111727.74 | 0/934651 | 0/4682240 | 0/4682240 | 0/0 | 8.382 | `phase6_emulator_internal_asic0_post_rbcam_recheck_header_mult3_delay_hit_t_runtime_mux_20260502.csv` |
| `header_multiplicity` | `mult4` | 69302 | 0 | 0 | None | 0.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 0/0 | 0.00/0.00 | 0/0/0 | 0.00/0.00 | 0/0 | 0/0 | 0/0 | 0/0 | 8.393 | `phase6_emulator_internal_asic0_post_rbcam_recheck_header_mult4_delay_hit_t_runtime_mux_20260502.csv` |
| `header_multiplicity` | `mult5` | 69303 | 61024 | 13 | 208.0 | 100.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 4687424/937504/937504/0 | 4687808/0 | 558289.91/0.00 | 0/937568/937568 | 111658.74/111658.74 | 0/935737 | 0/4687968 | 0/4688000 | 0/0 | 8.397 | `phase6_emulator_internal_asic0_post_rbcam_recheck_header_mult5_delay_hit_t_runtime_mux_20260502.csv` |
