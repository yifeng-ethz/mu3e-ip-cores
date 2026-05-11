# REPORT - B001

- bucket: `BASIC`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_b001.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_b001_test.sv`
- run: `make run_B001`

## Scenario

SWB RC firefly reset-link broadcast IDLE to RUN_PREP

## Stimulus

drive IDLE then RUN_PREP after the software-scale gap

## Pass Criteria

run_window_db records one legal transition and no local consumer backpressures

## Evidence

- Transcript: `tb_int/sim/B001/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
