# arb_hit_type0 UVM Scaffold

This directory contains the standalone UVM harness for `arb_hit_type0`.

- `arb_hit_type0_pkg.sv` declares the local protocol interfaces, environment config, typedefs, and UVM include order.
- `lcg_prng.sv` is the only PRNG source for future randomized sequences; use `+ARB_SEED=<int>`.
- `reg_pkg.sv` is the test-layer CSR constant source.
- `real_st_agent/` and `emu_st_agent/` are active Avalon-ST ingress sources with channel-range warnings.
- `csr_agent/` is the 5-bit word-address Avalon-MM master with 1-cycle read latency.
- `runctl_agent/` is the 9-bit run-control Avalon-ST source.
- `egress_st_agent/` is the passive selected-output monitor.
- `arb_hit_type0_scoreboard.sv` owns the reusable per-source FIFO, merge-FSM, counter, coverage-counter, and CSR-shadow model.
- `arb_hit_type0_assertions.sv` binds merged-packet and counter-coherence SVAs into the DUT.
- `arb_hit_type0_base_test.sv` provides reset, CSR, run-control, and counter-pair helper tasks.
- `arb_hit_type0_smoke_test.sv` is the only scaffold-owned test; directed bucket tests plug in later.
