# mutrig_lane_source_mux DV

This folder contains the IP-local UVM regression for `mutrig_lane_source_mux`.
The bench verifies the runtime real/emulator/round-robin source selection
contract in both real-valid modes:

- `REAL_ALWAYS_VALID=0`: valid-qualified decoded-byte source.
- `REAL_ALWAYS_VALID=1`: validless decoded-byte source used by the current FEB
  integration path.

The reusable UVM harness is under [`uvm/`](uvm/). The basic bucket uses one
parameterized directed test, `mlsm_directed_test`, with `+MLSM_CASE_ID=0..63`.
The Makefile maps B001-B064 to those case IDs.

Common commands:

```bash
make -C misc/mutrig_lane_source_mux/tb/uvm directed64
make -C misc/mutrig_lane_source_mux/tb/uvm bucket_frame
make -C misc/mutrig_lane_source_mux/tb/uvm soak
```

The default `soak` target uses `SOAK_ITERS=150000` and enforces
`MIN_SOAK_SECONDS=30`, so each of the three pressure runs fails if it completes
too quickly for the requested long-run pressure gate.

The validless real input counter advances every clock by design. Multi-word CSR
snapshot checks therefore make the selected-output side idle before reading
source-selected counters, and treat the raw real-input count as monotonic rather
than cycle-exact unless the build is `REAL_ALWAYS_VALID=0`.
