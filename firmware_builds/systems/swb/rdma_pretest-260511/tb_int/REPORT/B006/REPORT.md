# REPORT - B006

- bucket: `BASIC`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_b006.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_b006_test.sv`
- run: `make run_B006`

## Scenario

SWB RC full IDLE to RUNNING to IDLE walk with 1 ms gap

## Stimulus

drive the five-state run-control sequence with 1 ms-equivalent gaps

## Pass Criteria

every state transition is observed once and the stable window opens only in RUNNING

## Evidence

- Transcript: `tb_int/sim/B006/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
