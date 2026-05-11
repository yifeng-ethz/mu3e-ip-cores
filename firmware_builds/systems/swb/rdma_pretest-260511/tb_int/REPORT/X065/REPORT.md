# REPORT - X065

- bucket: `ERROR`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_x065.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_x065_test.sv`
- run: `make run_X065`

## Scenario

rdma CQE timeout

## Stimulus

drive one SQE then suppress CQE writeback

## Pass Criteria

SQE ingress is observed and CQE count remains zero

## Evidence

- Transcript: `tb_int/sim/X065/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
