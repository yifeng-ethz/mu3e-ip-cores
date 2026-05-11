# Phase 6 ASIC0 Emulator Internal Post-rbCAM Histogram Collection

- Timestamp: `2026-05-02T23:27:01`
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
| `header_multiplicity` | `mult2` | 69200 | 0 | 0 | None | 0.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 0/0 | 0.00/0.00 | 0/0/0 | 0.00/0.00 | 0/0 | 0/0 | 0/0 | 0/0 | 8.392 | `phase6_emulator_internal_asic0_post_rbcam_header_mult2_delay_hit_t_runtime_mux_20260502.csv` |
| `header_multiplicity` | `mult3` | 69201 | 61024 | 13 | 208.0 | 100.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 4694880/938976/938976/0 | 4694752/0 | 557710.70/0.00 | 0/938944/938944 | 111541.38/111541.38 | 0/937110 | 0/4694624 | 0/4694656 | 0/0 | 8.418 | `phase6_emulator_internal_asic0_post_rbcam_header_mult3_delay_hit_t_runtime_mux_20260502.csv` |
| `header_multiplicity` | `mult4` | 69202 | 0 | 0 | None | 0.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 0/0 | 0.00/0.00 | 0/0/0 | 0.00/0.00 | 0/0 | 0/0 | 0/0 | 0/0 | 8.392 | `phase6_emulator_internal_asic0_post_rbcam_header_mult4_delay_hit_t_runtime_mux_20260502.csv` |
| `header_multiplicity` | `mult5` | 69203 | 61056 | 13 | 208.0 | 100.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 4687232/937440/937440/0 | 4687296/0 | 558425.74/0.00 | 0/937472/937472 | 111686.67/111686.67 | 0/935641 | 0/4687392 | 0/4687392 | 0/0 | 8.394 | `phase6_emulator_internal_asic0_post_rbcam_header_mult5_delay_hit_t_runtime_mux_20260502.csv` |
