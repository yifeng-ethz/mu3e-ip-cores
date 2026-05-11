# REPORT - X005

- bucket: `ERROR`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_x005.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_x005_test.sv`
- run: `make run_X005`

## Scenario

truncated state word followed by legal recovery

## Stimulus

drive one truncated state word then a legal recovery state

## Pass Criteria

the malformed word is contained and the recovery path accounts for the held packet

## Evidence

- Transcript: `tb_int/sim/X005/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
