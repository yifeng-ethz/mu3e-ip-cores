# REPORT - E001

- bucket: `EDGE`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_e001.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_e001_test.sv`
- run: `make run_E001`

## Scenario

back-to-back zero-gap RC

## Stimulus

issue adjacent legal run-control transitions with zero idle gap

## Pass Criteria

transition order is preserved and no illegal intermediate state is observed

## Evidence

- Transcript: `tb_int/sim/E001/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
