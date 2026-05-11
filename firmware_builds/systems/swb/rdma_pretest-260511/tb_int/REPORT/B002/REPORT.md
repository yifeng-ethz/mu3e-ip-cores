# REPORT - B002

- bucket: `BASIC`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_b002.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_b002_test.sv`
- run: `make run_B002`

## Scenario

SWB RC RUN_PREP to SYNC broadcast

## Stimulus

drive RUN_PREP then SYNC after the software-scale gap

## Pass Criteria

run_window_db records the ordered transition and no local consumer backpressures

## Evidence

- Transcript: `tb_int/sim/B002/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
