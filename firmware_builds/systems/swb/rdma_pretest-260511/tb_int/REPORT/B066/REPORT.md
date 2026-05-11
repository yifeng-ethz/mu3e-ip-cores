# REPORT - B066

- bucket: `BASIC`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_b066.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_b066_test.sv`
- run: `make run_B066`

## Scenario

SWB DT rdma_subsystem CQE round-trip

## Stimulus

drive one legal SQE and observe one CQE completion

## Pass Criteria

SQ consumed count and CQ posted count both advance by one

## Evidence

- Transcript: `tb_int/sim/B066/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
