# REPORT - B003

- bucket: `BASIC`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_b003.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_b003_test.sv`
- run: `make run_B003`

## Scenario

SWB RC SYNC to RUNNING stable-window open

## Stimulus

drive SYNC then RUNNING and open the stable window

## Pass Criteria

stable-window state opens once and no datapath consumer sees a premature RUNNING

## Evidence

- Transcript: `tb_int/sim/B003/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
