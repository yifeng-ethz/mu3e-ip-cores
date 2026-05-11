# REPORT - P068

- bucket: `PROF`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_p068.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_p068_test.sv`
- run: `make run_P068`

## Scenario

sustained RQE ingress at line-rate structural scale

## Stimulus

drive a 128-RQE structural line-rate burst

## Pass Criteria

RQE, OPQ, and DMA ledgers reconcile without halt

## Evidence

- Transcript: `tb_int/sim/P068/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
