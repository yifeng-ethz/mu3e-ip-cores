# REPORT - X003

- bucket: `ERROR`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_x003.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_x003_test.sv`
- run: `make run_X003`

## Scenario

mid-flight RESET during host DMA issue

## Stimulus

accept one RQE/OPQ packet then reset during host DMA issue

## Pass Criteria

the in-flight packet is dropped and no DMA event reaches the host

## Evidence

- Transcript: `tb_int/sim/X003/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
