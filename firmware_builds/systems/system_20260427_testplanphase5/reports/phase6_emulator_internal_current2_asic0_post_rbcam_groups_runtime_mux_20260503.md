# Phase 6 ASIC0 Emulator Internal Current Rerun Post-rbCAM Histogram Collection

- Timestamp: `2026-05-03T00:55:10`
- Result: `PASS`
- Active lane: `0`
- Source mux: `all lanes forced to emulator`
- Emulator trigger mode: `internal-periodic`
- Emulator CSR setup: `enabled for active lane`
- Histogram selector: `filtered rbCAM egress at 0x0AB00`
- Header delay: `500` cycles
- Pulse high: `5` cycles

| Group | Case | Run | Hits | Nonzero | Peak [cyc] | In % | Low Out % | High Out % | Hist UF/OF | Hist UF/OF % | Hist Drops | Selector HP/RB/Emit/Drop | MTS0/1 Hits | MTS0/1 Hz | rbCAM InErr/Push/Pop | rbCAM Push/Pop Hz | rbCAM Overwrite/Miss | Source R/E In | Source R/E Out | Source R/E Drop | Window s | CSV |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `rate` | `10k` | 69600 | 3814 | 2 | 192.0 | 100.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 292812/58562/58562/0 | 292806/0 | 34872.41/0.00 | 0/58562/58562 | 6974.58/6974.58 | 0/58448 | 0/292808 | 0/292810 | 0/0 | 8.396 | `phase6_emulator_internal_current2_asic0_post_rbcam_rate_10k_delay_hit_t_runtime_mux_20260503.csv` |
| `rate` | `100k` | 69601 | 45776 | 6 | 192.0 | 100.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 3047210/703220/703220/0 | 3047230/0 | 364091.95/0.00 | 0/703228/703226 | 84023.74/84023.50 | 0/701842 | 0/3047210 | 0/3047244 | 0/0 | 8.369 | `phase6_emulator_internal_current2_asic0_post_rbcam_rate_100k_delay_hit_t_runtime_mux_20260503.csv` |
| `rate` | `500k` | 69602 | 244138 | 16 | 0.0 | 100.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 15343102/3747938/3747938/0 | 15343264/0 | 1831272.16/0.00 | 0/3748014/3748014 | 447338.57/447338.57 | 0/3740711 | 0/15343276 | 0/15343288 | 0/0 | 8.378 | `phase6_emulator_internal_current2_asic0_post_rbcam_rate_500k_delay_hit_t_runtime_mux_20260503.csv` |
| `rate` | `1M` | 69603 | 488278 | 16 | 192.0 | 100.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 30739537/7508928/7508928/0 | 30739520/0 | 3665121.55/0.00 | 0/7508886/7508886 | 895296.34/895296.34 | 0/7494220 | 0/30741080 | 0/30740610 | 0/0 | 8.387 | `phase6_emulator_internal_current2_asic0_post_rbcam_rate_1M_delay_hit_t_runtime_mux_20260503.csv` |
| `header_multiplicity` | `mult2` | 69604 | 7628 | 3 | 208.0 | 100.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 586244/117252/117252/0 | 586240/0 | 69969.34/0.00 | 0/117248/117248 | 13993.87/13993.87 | 0/117019 | 0/586228 | 0/586236 | 0/0 | 8.379 | `phase6_emulator_internal_current2_asic0_post_rbcam_header_mult2_delay_hit_t_runtime_mux_20260503.csv` |
| `header_multiplicity` | `mult3` | 69605 | 11442 | 3 | 208.0 | 100.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 879090/175818/175818/0 | 879102/0 | 104608.02/0.00 | 0/175824/175824 | 20922.03/20922.03 | 229/175481 | 0/879120 | 0/879126 | 0/0 | 8.404 | `phase6_emulator_internal_current2_asic0_post_rbcam_header_mult3_delay_hit_t_runtime_mux_20260503.csv` |
| `header_multiplicity` | `mult4` | 69606 | 15264 | 4 | 208.0 | 100.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 1169392/233872/233872/0 | 1169424/0 | 139718.86/0.00 | 0/233872/233872 | 27942.24/27942.24 | 0/233415 | 0/1169376 | 0/1169376 | 0/0 | 8.370 | `phase6_emulator_internal_current2_asic0_post_rbcam_header_mult4_delay_hit_t_runtime_mux_20260503.csv` |
| `header_multiplicity` | `mult5` | 69607 | 19070 | 5 | 208.0 | 100.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 1462170/292430/292430/0 | 1462150/0 | 174435.22/0.00 | 0/292430/292430 | 34887.04/34887.04 | 456/291859 | 0/1462110 | 0/1462120 | 0/0 | 8.382 | `phase6_emulator_internal_current2_asic0_post_rbcam_header_mult5_delay_hit_t_runtime_mux_20260503.csv` |
