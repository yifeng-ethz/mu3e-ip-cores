# REPORT - P001

- bucket: `PROF`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_p001.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_p001_test.sv`
- run: `make run_P001`

## Scenario

long RUNNING window structural load

## Stimulus

hold RUNNING while driving a balanced 32-RQE structural load

## Pass Criteria

RQE, CQE, OPQ, and DMA ledgers reconcile across the long window

## Evidence

- Transcript: `tb_int/sim/P001/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
