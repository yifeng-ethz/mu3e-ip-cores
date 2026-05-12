# COSIM_SANITY 1ms Periodic All-Channel Summary

## Configuration

- Source mode: periodic
- ASIC count: 8
- Channel mask: 0xFFFFFFFF per ASIC source
- Hit period: 5000 x 8 ns
- Run window: 125000 x 8 ns
- Expected hits: 6400
- Run-control concept: 0x10 -> 0x11 -> 0x12 -> drain -> 0x13

## Checkpoints

| Checkpoint | Count | p05 cycles | p50 cycles | p95 cycles | Status |
|---|---:|---:|---:|---:|---|
| pre-rbCAM | 6400 | 0.000 | 0.000 | 0.000 | PASS |
| post-rbCAM | 6400 | 0.000 | 0.000 | 0.000 | PASS |
| FEB egress | 6400 | 2530.500 | 3290.500 | 4050.500 | PASS |
| SWB ingress | 6400 | 2531.750 | 3291.750 | 4051.750 | PASS |
| OPQ egress | 6400 | 10160.675 | 50299.750 | 91312.250 | PASS |
| RDMA egress | 6400 | 10165.600 | 50304.000 | 91315.825 | PASS |

## Packet Steering

| Packet type | Count |
|---|---:|
| Hit | 132 |
| Slow control | 0 |
| Run control | 0 |

## Raw Waveform Capture

| Boundary | Cycles captured | Valid cycles |
|---|---:|---:|
| FEB egress | 438030 | 24088 |
| SWB ingress | 1752124 | 24088 |

## Lossless Checks

- pass_hits: 6400
- fail_hits: 0
- ghost_source_generation_hits: 0
- ghost_pre_rbcam_hits: 0
- ghost_post_rbcam_hits: 0
- ghost_opq_ingress_hits: 0
- ghost_opq_egress_hits: 0
- ghost_dma_hits: 0
- opq_drop_counter_total: 0
- opq_handle_fifo_overflow_total: 0
- issue_count: 0
- expected_hits: 6400
- actual_hits: 6400
- missing_hits: 0
- ghost_hits: 0
- fifo_overflow: 0x0
- fifo_underflow: 0x0

## Verdict

PASS: all six checkpoints reached 6400 hits with no analyzer issues.
