# RN.BASIC.172 rate (CSR counters)

Notes: board measured total TBD

| IP | counter | measured | sim | expected | sim_delta_pct | board_delta_pct |
|---|---|---:|---:|---:|---:|---:|
| arb_hit_type0 | SELECTED_COUNT (lane 1) | -- | 15,637 | 15,625 | 0.08% | -- |
| arb_hit_type0 | SELECTED_COUNT (lane 3) | -- | 15,708 | 15,625 | 0.53% | -- |
| arb_hit_type0 | SELECTED_COUNT (lane 5) | -- | 15,625 | 15,625 | 0.00% | -- |
| arb_hit_type0 | SELECTED_COUNT (lane 7) | -- | 15,545 | 15,625 | -0.51% | -- |
| arb_hit_type0 | DROPPED_HITS | -- | 0 | 0 | 0.00% | -- |
| histogram_statistics_v2 | TOTAL_HITS_CSR13 | -- | 62,515 | 62,500 | 0.02% | -- |
| histogram_statistics_v2 | LAST_INTERVAL_TOTAL_HITS_CSR17 | -- | 62,515 | 62,500 | 0.02% | -- |
| checkpoint | feb_egress_hits | -- | 62,515 | 62,500 | 0.02% | -- |
| checkpoint | opq_egress_hits | -- | 62,515 | 62,500 | 0.02% | -- |
| checkpoint | post_rbcam_hits | -- | 62,515 | 62,500 | 0.02% | -- |
| checkpoint | pre_rbcam_hits | -- | 62,515 | 62,500 | 0.02% | -- |
| checkpoint | rdma_hits | -- | 62,515 | 62,500 | 0.02% | -- |
| checkpoint | source_generation_hits | -- | 62,515 | 62,500 | 0.02% | -- |
| checkpoint | swb_ingress_hits | -- | 62,515 | 62,500 | 0.02% | -- |
| ring_buffer_cam_rbcam_0 | push_cnt | -- | 0 | 15,625 | -100.00% | -- |
| ring_buffer_cam_rbcam_0 | pop_cnt | -- | 0 | 15,625 | -100.00% | -- |
| ring_buffer_cam_rbcam_1 | push_cnt | -- | 31,262 | 15,625 | 100.08% | -- |
| ring_buffer_cam_rbcam_1 | pop_cnt | -- | 31,262 | 15,625 | 100.08% | -- |
| ring_buffer_cam_rbcam_2 | push_cnt | -- | 0 | 15,625 | -100.00% | -- |
| ring_buffer_cam_rbcam_2 | pop_cnt | -- | 0 | 15,625 | -100.00% | -- |
| ring_buffer_cam_rbcam_3 | push_cnt | -- | 31,253 | 15,625 | 100.02% | -- |
| ring_buffer_cam_rbcam_3 | pop_cnt | -- | 31,253 | 15,625 | 100.02% | -- |
| error_counters | corun_ghost_hits | -- | 0 | 0 | 0.00% | -- |
| error_counters | corun_missing_hits | -- | 0 | 0 | 0.00% | -- |
| error_counters | fifo_overflow | -- | 0 | 0 | 0.00% | -- |
| error_counters | fifo_underflow | -- | 0 | 0 | 0.00% | -- |
| error_counters | filtered_failed_hits | -- | 0 | 0 | 0.00% | -- |
| error_counters | sim_returncode | -- | 0 | 0 | 0.00% | -- |
| error_counters | trace_fail_hits | -- | 0 | 0 | 0.00% | -- |
| error_counters | trace_issue_count | -- | 0 | 0 | 0.00% | -- |
