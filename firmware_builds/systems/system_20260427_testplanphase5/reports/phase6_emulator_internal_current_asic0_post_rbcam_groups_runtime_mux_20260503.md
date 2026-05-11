# Phase 6 ASIC0 Emulator Internal Current Post-rbCAM Histogram Collection

- Timestamp: `2026-05-03T00:49:03`
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
| `rate` | `10k` | 69500 | 0 | 0 | None | 0.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 0/0/0/0 | 0/0 | 0.00/0.00 | 0/0/0 | 0.00/0.00 | 0/0 | 0/0 | 0/0 | 0/0 | 8.419 | `phase6_emulator_internal_current_asic0_post_rbcam_rate_10k_delay_hit_t_runtime_mux_20260503.csv` |
| `rate` | `100k` | 69501 | 45778 | 6 | 64.0 | 100.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 3048016/703386/703386/0 | 3047992/0 | 363610.76/0.00 | 0/703386/703386 | 83910.56/83910.56 | 0/702012 | 0/3048026 | 0/3048026 | 0/0 | 8.383 | `phase6_emulator_internal_current_asic0_post_rbcam_rate_100k_delay_hit_t_runtime_mux_20260503.csv` |
| `rate` | `500k` | 69502 | 244140 | 16 | 64.0 | 100.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 15373676/3755450/3755450/0 | 15373392/0 | 1826388.48/0.00 | 0/3755468/3755468 | 446156.81/446156.81 | 0/3748079 | 0/15373850 | 0/15373924 | 0/0 | 8.417 | `phase6_emulator_internal_current_asic0_post_rbcam_rate_500k_delay_hit_t_runtime_mux_20260503.csv` |
| `rate` | `1M` | 69503 | 488280 | 16 | 0.0 | 100.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 30674397/7492986/7492992/0 | 30672572/0 | 3659381.35/0.00 | 0/7492482/7492482 | 893888.16/893888.16 | 0/7477850 | 0/30671560 | 0/30671852 | 0/0 | 8.382 | `phase6_emulator_internal_current_asic0_post_rbcam_rate_1M_delay_hit_t_runtime_mux_20260503.csv` |
| `header_multiplicity` | `mult2` | 69504 | 7628 | 3 | 208.0 | 100.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 585776/117156/117156/0 | 585768/0 | 69769.57/0.00 | 0/117156/117156 | 13954.20/13954.20 | 0/116927 | 0/585748 | 0/585752 | 0/0 | 8.396 | `phase6_emulator_internal_current_asic0_post_rbcam_header_mult2_delay_hit_t_runtime_mux_20260503.csv` |
| `header_multiplicity` | `mult3` | 69505 | 11442 | 3 | 208.0 | 100.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 877914/175578/175578/0 | 877998/0 | 104791.45/0.00 | 0/175608/175608 | 20959.29/20959.29 | 228/175265 | 0/878076 | 0/878076 | 0/0 | 8.379 | `phase6_emulator_internal_current_asic0_post_rbcam_header_mult3_delay_hit_t_runtime_mux_20260503.csv` |
| `header_multiplicity` | `mult4` | 69506 | 15256 | 4 | 208.0 | 100.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 1174896/234984/234984/0 | 1174904/0 | 139554.12/0.00 | 0/234976/234976 | 27910.25/27910.25 | 0/234517 | 0/1174872 | 0/1174872 | 0/0 | 8.419 | `phase6_emulator_internal_current_asic0_post_rbcam_header_mult4_delay_hit_t_runtime_mux_20260503.csv` |
| `header_multiplicity` | `mult5` | 69507 | 19080 | 5 | 208.0 | 100.000000 | 0.000000 | 0.000000 | 0/0 | 0.000000/0.000000 | 0 | 1465190/293040/293040/0 | 1465120/0 | 174570.88/0.00 | 0/293010/293010 | 34912.51/34912.51 | 458/292437 | 0/1465070 | 0/1465080 | 0/0 | 8.393 | `phase6_emulator_internal_current_asic0_post_rbcam_header_mult5_delay_hit_t_runtime_mux_20260503.csv` |
