# REPORT - B068

- bucket: `BASIC`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_b068.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_b068_test.sv`
- run: `make run_B068`

## Scenario

SWB DT OPQ 4-lane fairness

## Stimulus

drive four sources with 16 OPQ packets each

## Pass Criteria

per-lane accepted and emitted counts remain balanced with zero drops

## Evidence

- Transcript: `tb_int/sim/B068/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
