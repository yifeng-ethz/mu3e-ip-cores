# REPORT - E003

- bucket: `EDGE`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_e003.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_e003_test.sv`
- run: `make run_E003`

## Scenario

frame boundary RUNNING open with one packet per lane

## Stimulus

open RUNNING at a frame boundary while each lane has one packet

## Pass Criteria

all four lane packets emit and the DMA event closes once

## Evidence

- Transcript: `tb_int/sim/E003/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
