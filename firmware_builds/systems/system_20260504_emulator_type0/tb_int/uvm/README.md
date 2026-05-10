# tb_int UVM Infra

Reusable code lives under `uvm/common/`; focus-build bindings live under `uvm/system_20260504_emulator_type0/`.

Run the infrastructure smoke:

```bash
make run_tb_int_smoke_test SEED=1
```

The smoke drives 16 deterministic records across Stage A, Pre-RbCAM, Post-RbCAM, and FEB-egress taps. Directed BASIC/EDGE/PROF/ERROR cases are intentionally not implemented yet.

Lineage anchors:
- `run_window_db.sv` mirrors `packet_scheduler/tb_int/uvm/tb_int_pkg.sv:160-236`.
- `hit_key_pkg.sv` mirrors `tb_int_pkg.sv:1117-1138` for `hit_key_t`.
- `per_bucket_ledger_scoreboard.sv` mirrors ledger declarations and reconciliation from `tb_int_pkg.sv:1300-1394` and `2656-2829`.
- `l2_fifo_commit_monitor.sv` mirrors the monotonic Stage-A id assignment from `tb_int_pkg.sv:3773-3809`.
- `runctl_phy_agent.sv` mirrors run-window driver calls from `tb_int_pkg.sv:4321-4411`.
