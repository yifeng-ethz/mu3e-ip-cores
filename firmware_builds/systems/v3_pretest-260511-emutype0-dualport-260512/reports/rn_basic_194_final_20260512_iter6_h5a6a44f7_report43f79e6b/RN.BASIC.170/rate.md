# RN.BASIC.170 rate (CSR counters)

Notes: board measured total TBD

| IP | counter | measured | sim | expected | sim_delta_pct | board_delta_pct |
|---|---|---:|---:|---:|---:|---:|
| arb_hit_type0 | SELECTED_COUNT (lane 0) | -- | 15,600 | 15,625 | -0.16% | -- |
| arb_hit_type0 | SELECTED_COUNT (lane 2) | -- | 15,791 | 15,625 | 1.06% | -- |
| arb_hit_type0 | SELECTED_COUNT (lane 4) | -- | 15,601 | 15,625 | -0.15% | -- |
| arb_hit_type0 | SELECTED_COUNT (lane 6) | -- | 15,631 | 15,625 | 0.04% | -- |
| arb_hit_type0 | DROPPED_HITS | -- | 0 | 0 | 0.00% | -- |
| histogram_statistics_v2 | TOTAL_HITS_CSR13 | -- | 62,623 | 62,500 | 0.20% | -- |
| histogram_statistics_v2 | LAST_INTERVAL_TOTAL_HITS_CSR17 | -- | 62,623 | 62,500 | 0.20% | -- |
| checkpoint | feb_egress_hits | -- | 62,623 | 62,500 | 0.20% | -- |
| checkpoint | opq_egress_hits | -- | 62,623 | 62,500 | 0.20% | -- |
| checkpoint | post_rbcam_hits | -- | 62,623 | 62,500 | 0.20% | -- |
| checkpoint | pre_rbcam_hits | -- | 62,623 | 62,500 | 0.20% | -- |
| checkpoint | rdma_hits | -- | 62,623 | 62,500 | 0.20% | -- |
| checkpoint | source_generation_hits | -- | 62,623 | 62,500 | 0.20% | -- |
| checkpoint | swb_ingress_hits | -- | 62,623 | 62,500 | 0.20% | -- |
| ring_buffer_cam_rbcam_0 | push_cnt | -- | 31,201 | 15,625 | 99.69% | -- |
| ring_buffer_cam_rbcam_0 | pop_cnt | -- | 31,201 | 15,625 | 99.69% | -- |
| ring_buffer_cam_rbcam_1 | push_cnt | -- | 0 | 15,625 | -100.00% | -- |
| ring_buffer_cam_rbcam_1 | pop_cnt | -- | 0 | 15,625 | -100.00% | -- |
| ring_buffer_cam_rbcam_2 | push_cnt | -- | 31,422 | 15,625 | 101.10% | -- |
| ring_buffer_cam_rbcam_2 | pop_cnt | -- | 31,422 | 15,625 | 101.10% | -- |
| ring_buffer_cam_rbcam_3 | push_cnt | -- | 0 | 15,625 | -100.00% | -- |
| ring_buffer_cam_rbcam_3 | pop_cnt | -- | 0 | 15,625 | -100.00% | -- |
| error_counters | corun_ghost_hits | -- | 0 | 0 | 0.00% | -- |
| error_counters | corun_missing_hits | -- | 0 | 0 | 0.00% | -- |
| error_counters | fifo_overflow | -- | 0 | 0 | 0.00% | -- |
| error_counters | fifo_underflow | -- | 0 | 0 | 0.00% | -- |
| error_counters | filtered_failed_hits | -- | 0 | 0 | 0.00% | -- |
| error_counters | sim_returncode | -- | 0 | 0 | 0.00% | -- |
| error_counters | trace_fail_hits | -- | 0 | 0 | 0.00% | -- |
| error_counters | trace_issue_count | -- | 0 | 0 | 0.00% | -- |
