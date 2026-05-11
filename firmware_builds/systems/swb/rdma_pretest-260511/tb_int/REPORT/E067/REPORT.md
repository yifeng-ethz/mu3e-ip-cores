# REPORT - E067

- bucket: `EDGE`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_e067.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_e067_test.sv`
- run: `make run_E067`

## Scenario

lane-3 frame-boundary cluster

## Stimulus

drive a lane-3 cluster at the selected frame boundary

## Pass Criteria

OPQ preserves lane-3 ordering and the DMA event closes once

## Evidence

- Transcript: `tb_int/sim/E067/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
