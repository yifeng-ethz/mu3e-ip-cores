# REPORT - B008

- bucket: `BASIC`
- status: `PASS`
- alias: `B-RC-CSR-001` mapped to lint-legal `B008`
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_b008.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_b008_test.sv`
- run: `make run_B008`

## Scenario

CSR-toggle RC fallback

## Stimulus

toggle the SWB-local CSR run-control fallback once

## Pass Criteria

local run-state shadow changes without replacing the reset-link nominal path

## Evidence

- Transcript: `tb_int/sim/B008/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
