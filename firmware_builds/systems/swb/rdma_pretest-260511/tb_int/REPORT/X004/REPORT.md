# REPORT - X004

- bucket: `ERROR`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_x004.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_x004_test.sv`
- run: `make run_X004`

## Scenario

truncated run-control state word is rejected

## Stimulus

drive a truncated state word on the structural reset-link path

## Pass Criteria

the state shadow remains unchanged and no packet is emitted

## Evidence

- Transcript: `tb_int/sim/X004/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
