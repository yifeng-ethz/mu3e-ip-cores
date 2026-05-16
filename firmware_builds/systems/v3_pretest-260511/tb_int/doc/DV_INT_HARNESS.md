# DV_INT_HARNESS.md: v3_pretest-260511 tb_int harness notes

**DUT:** `feb_system_v3` &nbsp; **Date:** 2026-05-16
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

Current bridge-free Phase A evidence covers B065 through B069, `RC_EMUL`, and
the source-mux/frame-parser cosim in the old dual UVM environment with
DEBUG_LEVEL=2 per-hit scoreboard closure. The generated `feb_system_v3`
`synthesis/` tree also compiles into the harness and is instantiated by
`BIND_REAL_DUT=1` for the B067 bind smoke.

The bind smoke keeps the generated Qsys system present as `u_dut`, but the old
dual environment still drives and monitors the behavioral shell taps used by
the existing per-hit scoreboard. Generated/vendor assertions below `u_dut` are
disabled in bind mode so dormant unconnected fabric does not mask the UVM
scoreboard result.

No UCDB/code-coverage closure, full continuous all-buckets frame, RDMA SQE/CQE
cosim, board run, or full generated-system top-level IO exercise is claimed by
this phase.
