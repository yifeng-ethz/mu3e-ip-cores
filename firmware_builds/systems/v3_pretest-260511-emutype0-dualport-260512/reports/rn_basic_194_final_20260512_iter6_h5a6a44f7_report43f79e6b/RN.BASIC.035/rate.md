# RN.BASIC.035 rate (CSR counters)

Notes: board measured total TBD

| IP | counter | measured | sim | expected | sim_delta_pct | board_delta_pct |
|---|---|---:|---:|---:|---:|---:|
| arb_hit_type0 | SELECTED_COUNT (lane 1) | -- | 11,744 | 11,718.750 | 0.22% | -- |
| arb_hit_type0 | SELECTED_COUNT (lane 3) | -- | 11,744 | 11,718.750 | 0.22% | -- |
| arb_hit_type0 | SELECTED_COUNT (lane 5) | -- | 11,712 | 11,718.750 | -0.06% | -- |
| arb_hit_type0 | SELECTED_COUNT (lane 7) | -- | 11,712 | 11,718.750 | -0.06% | -- |
| arb_hit_type0 | DROPPED_HITS | -- | 0 | 0 | 0.00% | -- |
| histogram_statistics_v2 | TOTAL_HITS_CSR13 | -- | 46,912 | 46,875 | 0.08% | -- |
| histogram_statistics_v2 | LAST_INTERVAL_TOTAL_HITS_CSR17 | -- | 46,912 | 46,875 | 0.08% | -- |
| checkpoint | feb_egress_hits | -- | 46,912 | 46,875 | 0.08% | -- |
| checkpoint | opq_egress_hits | -- | 46,912 | 46,875 | 0.08% | -- |
| checkpoint | post_rbcam_hits | -- | 46,912 | 46,875 | 0.08% | -- |
| checkpoint | pre_rbcam_hits | -- | 46,912 | 46,875 | 0.08% | -- |
| checkpoint | rdma_hits | -- | 46,912 | 46,875 | 0.08% | -- |
| checkpoint | source_generation_hits | -- | 46,912 | 46,875 | 0.08% | -- |
| checkpoint | swb_ingress_hits | -- | 46,912 | 46,875 | 0.08% | -- |
| ring_buffer_cam_rbcam_0 | push_cnt | -- | 0 | 11,718.750 | -100.00% | -- |
| ring_buffer_cam_rbcam_0 | pop_cnt | -- | 0 | 11,718.750 | -100.00% | -- |
| ring_buffer_cam_rbcam_1 | push_cnt | -- | 23,456 | 11,718.750 | 100.16% | -- |
| ring_buffer_cam_rbcam_1 | pop_cnt | -- | 23,456 | 11,718.750 | 100.16% | -- |
| ring_buffer_cam_rbcam_2 | push_cnt | -- | 0 | 11,718.750 | -100.00% | -- |
| ring_buffer_cam_rbcam_2 | pop_cnt | -- | 0 | 11,718.750 | -100.00% | -- |
| ring_buffer_cam_rbcam_3 | push_cnt | -- | 23,456 | 11,718.750 | 100.16% | -- |
| ring_buffer_cam_rbcam_3 | pop_cnt | -- | 23,456 | 11,718.750 | 100.16% | -- |
| error_counters | corun_ghost_hits | -- | 0 | 0 | 0.00% | -- |
| error_counters | corun_missing_hits | -- | 0 | 0 | 0.00% | -- |
| error_counters | fifo_overflow | -- | 0 | 0 | 0.00% | -- |
| error_counters | fifo_underflow | -- | 0 | 0 | 0.00% | -- |
| error_counters | filtered_failed_hits | -- | 0 | 0 | 0.00% | -- |
| error_counters | sim_returncode | -- | 0 | 0 | 0.00% | -- |
| error_counters | trace_fail_hits | -- | 0 | 0 | 0.00% | -- |
| error_counters | trace_issue_count | -- | 0 | 0 | 0.00% | -- |
