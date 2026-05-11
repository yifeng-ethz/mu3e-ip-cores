# REPORT - B007

- bucket: `BASIC`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_b007.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_b007_test.sv`
- run: `make run_B007`

## Scenario

SWB RC RUN_NUMBER increment before RUN_PREP

## Stimulus

increment RUN_NUMBER before entering RUN_PREP

## Pass Criteria

all SWB-local state shadows observe the new run number once

## Evidence

- Transcript: `tb_int/sim/B007/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
