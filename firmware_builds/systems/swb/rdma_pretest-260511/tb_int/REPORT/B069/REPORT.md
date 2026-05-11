# REPORT - B069

- bucket: `BASIC`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_b069.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_b069_test.sv`
- run: `make run_B069`

## Scenario

SWB DT PCIe x8 DMA capture matches scoreboard

## Stimulus

drive one eight-beat host DMA capture

## Pass Criteria

DMA beat and end-of-event counts match the scoreboard

## Evidence

- Transcript: `tb_int/sim/B069/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
