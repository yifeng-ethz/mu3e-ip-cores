# DV_INT_HARNESS.md - v3_pretest-260511 tb_int harness notes

**Companion docs:** [DV_INT_PLAN.md](DV_INT_PLAN.md), [DV_BASIC.md](DV_BASIC.md), [BUG_HISTORY.md](BUG_HISTORY.md), [../README.md](../README.md)

## 1. Common Reuse

The harness keeps the Apr 27 reference common layer read-only and reuses compatible files through symlinks under `tb_int/uvm/common/`. The linked infrastructure includes `mutrig_phy_agent`, `runctl_phy_agent`, `sc_phy_agent`, `lvds_decoded_monitor`, `rbcam_egress_monitor`, `l2_fifo_commit_monitor`, `run_window_db`, `hit_record`, `hit_key_pkg`, `hit_tap_if`, and the base per-bucket ledger scoreboard.

The v3-specific common additions are local files:

- `debug_fill_monitor/`
- `debug_l2_sidecar_monitor/`
- `debug_pre_rbcam_sidecar_monitor/`
- `debug_post_rbcam_sidecar_monitor/`
- `debug_feb_egress_sidecar_monitor/`
- `feb_egress_monitor/`

## 2. DUT Layer

The v3 layer lives under `tb_int/uvm/v3_pretest-260511/` and provides:

- `mutrig_l2_commit_if.sv` - emulator L2 commit boundary using `pending_valid && l2_wr_ready`.
- `mutrig_frame_deassembly_decoded_if.sv` - decoded hit_type0 tap boundary.
- FEB egress uses `hit_tap_if` at the legacy upload_pkt_mux egress boundary.
- `tb_int_dual_env.sv` - nominal and debug environments sharing the v3 ledger scoreboard.
- `tb_int_base_test.sv`, `tb_int_basic_sequences.sv`, and B065 through B069 tests.

## 3. Execution Modes

- `isolated`: `make run_B065`, `make run_B066`, `make run_B067`, `make run_B068`, `make run_B069`.
- `bucket_frame`: hook present as `make all_buckets_frame`; full continuous BASIC execution waits for complete bucket implementation.
- `all_buckets_frame`: not claimed in this phase.

## 4. Non-Claims

Current B065 through B069 evidence is harness-shell smoke evidence while the DUT bind layer is being widened. BUG-001-R is redesignated because this FEB-only generated tree correctly exposes legacy `feb_frame_assembly` plus `upload_pkt_mux`; RDMA cosim belongs to task #48.
