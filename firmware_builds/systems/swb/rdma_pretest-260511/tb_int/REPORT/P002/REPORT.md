# REPORT - P002

- bucket: `PROF`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_p002.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_p002_test.sv`
- run: `make run_P002`

## Scenario

RUN_NUMBER bumps between short host batches

## Stimulus

bump RUN_NUMBER between two short balanced host batches

## Pass Criteria

both short batches reconcile and no stale sidecar crosses the run boundary

## Evidence

- Transcript: `tb_int/sim/P002/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
