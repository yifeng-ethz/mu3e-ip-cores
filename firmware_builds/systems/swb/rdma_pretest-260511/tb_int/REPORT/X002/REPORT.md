# REPORT - X002

- bucket: `ERROR`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_x002.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_x002_test.sv`
- run: `make run_X002`

## Scenario

mid-flight RESET during RUN_PREP state shadow update

## Stimulus

assert reset while RUN_PREP is being reflected into local shadows

## Pass Criteria

the shadow returns to IDLE without ghost datapath activity

## Evidence

- Transcript: `tb_int/sim/X002/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
