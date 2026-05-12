# RN.BASIC.078 rate (CSR counters)

Notes: board measured total TBD

| IP | counter | measured | sim | expected | sim_delta_pct | board_delta_pct |
|---|---|---:|---:|---:|---:|---:|
| arb_hit_type0 | SELECTED_COUNT (lane 1) | -- | 245 | 244 | 0.41% | -- |
| arb_hit_type0 | DROPPED_HITS | -- | 0 | 0 | 0.00% | -- |
| histogram_statistics_v2 | TOTAL_HITS_CSR13 | -- | 245 | 244 | 0.41% | -- |
| histogram_statistics_v2 | LAST_INTERVAL_TOTAL_HITS_CSR17 | -- | 245 | 244 | 0.41% | -- |
| checkpoint | feb_egress_hits | -- | 245 | 244 | 0.41% | -- |
| checkpoint | opq_egress_hits | -- | 245 | 244 | 0.41% | -- |
| checkpoint | post_rbcam_hits | -- | 245 | 244 | 0.41% | -- |
| checkpoint | pre_rbcam_hits | -- | 245 | 244 | 0.41% | -- |
| checkpoint | rdma_hits | -- | 245 | 244 | 0.41% | -- |
| checkpoint | source_generation_hits | -- | 245 | 244 | 0.41% | -- |
| checkpoint | swb_ingress_hits | -- | 245 | 244 | 0.41% | -- |
| ring_buffer_cam_rbcam_0 | push_cnt | -- | 0 | 61 | -100.00% | -- |
| ring_buffer_cam_rbcam_0 | pop_cnt | -- | 0 | 61 | -100.00% | -- |
| ring_buffer_cam_rbcam_1 | push_cnt | -- | 245 | 61 | 301.64% | -- |
| ring_buffer_cam_rbcam_1 | pop_cnt | -- | 245 | 61 | 301.64% | -- |
| ring_buffer_cam_rbcam_2 | push_cnt | -- | 0 | 61 | -100.00% | -- |
| ring_buffer_cam_rbcam_2 | pop_cnt | -- | 0 | 61 | -100.00% | -- |
| ring_buffer_cam_rbcam_3 | push_cnt | -- | 0 | 61 | -100.00% | -- |
| ring_buffer_cam_rbcam_3 | pop_cnt | -- | 0 | 61 | -100.00% | -- |
| error_counters | corun_ghost_hits | -- | 0 | 0 | 0.00% | -- |
| error_counters | corun_missing_hits | -- | 0 | 0 | 0.00% | -- |
| error_counters | fifo_overflow | -- | 0 | 0 | 0.00% | -- |
| error_counters | fifo_underflow | -- | 0 | 0 | 0.00% | -- |
| error_counters | filtered_failed_hits | -- | 0 | 0 | 0.00% | -- |
| error_counters | sim_returncode | -- | 0 | 0 | 0.00% | -- |
| error_counters | trace_fail_hits | -- | 0 | 0 | 0.00% | -- |
| error_counters | trace_issue_count | -- | 0 | 0 | 0.00% | -- |
