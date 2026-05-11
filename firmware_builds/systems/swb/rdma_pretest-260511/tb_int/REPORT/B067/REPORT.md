# REPORT - B067

- bucket: `BASIC`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_b067.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_b067_test.sv`
- run: `make run_B067`

## Scenario

SWB DT sidecar lineage at FEB-side rdma SQE ingress

## Stimulus

drive one SQE with DEBUG_LEVEL 2 sidecar identity

## Pass Criteria

nominal payload and sidecar identity reconcile through the selected monitors

## Evidence

- Transcript: `tb_int/sim/B067/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
