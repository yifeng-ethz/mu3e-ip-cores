# Phase 4 Emulator Type0 Round 1 SIM Evidence

Build: `v3_pretest-260511-emulator-type0-260512`

Purpose: validate the emulator-type0 FEB-to-SWB lifetime path after refactoring
the FEB v3 datapath Qsys to one `emulator_mutrig` source, explicit 8-lane
`hit_type0_fanout8`, and `arb_hit_type0_supercore`.

Command:

```sh
make run_swb_corun_header_sync \
  QUESTA_HOME=/data1/questaone_sim-2026.1_1/questasim \
  OPQ_SOURCE_MODE=native_sv_signoff \
  OPQ_LANE_FIFO_DEPTH=65536 \
  OPQ_TICKET_FIFO_DEPTH=65536 \
  ASIC_COUNT=8 \
  RUN_WINDOW_8NS=125000 \
  HEADER_SYNC_PHASE_8NS=100 \
  HEADER_SYNC_BURST_COUNT=1 \
  HEADER_SYNC_ASIC_STAGGER_8NS=16
```

Verdict: PASS.

- `FEB_SWB_CORUN_PLAIN_PASS expected_hits=35328 dma_payload_words=8832 opq_beats=36798`
- `TRACE_DEBUG_PASS hits=35328 channels=0..31 asics=0..7`
- `FEB_SWB_CORUN_TRACE_PASS`
- `LIFETIME_DISLIN_PASS`, DISLIN warnings `0`
- Drops and FIFO overflows: `0`

Checkpoint lifetimes:

| checkpoint | n | p05 | p50 | p95 |
|---|---:|---:|---:|---:|
| pre-rbCAM virtual MuTRiG model | 35328 | 753.000 | 835.000 | 917.000 |
| post-rbCAM DEBUG age reference | 3136 | 2012.000 | 2070.000 | 2128.000 |
| FEB egress | 35328 | 2946.500 | 3496.500 | 4128.500 |
| OPQ ingress | 35328 | 2947.750 | 3497.750 | 4129.750 |
| OPQ egress | 35328 | 9290.250 | 50754.750 | 92219.250 |

Evidence files:

- `tb_int/feb_swb_corun/report_header_sync/feb_swb_lifetime_hist.png`
- `tb_int/feb_swb_corun/report_header_sync/feb_swb_lifetime_hist_stats.csv`
- `tb_int/feb_swb_corun/report_header_sync/feb_swb_rbcam_reference_stats.csv`
- `tb_int/feb_swb_corun/report_header_sync/feb_swb_trace_debug_summary.txt`
- `tb_int/feb_swb_corun/report_header_sync/feb_swb_range_validation.csv`
