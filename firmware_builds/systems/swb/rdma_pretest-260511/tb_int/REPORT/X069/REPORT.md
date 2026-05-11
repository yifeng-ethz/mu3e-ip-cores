# REPORT - X069

- bucket: `ERROR`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_x069.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_x069_test.sv`
- run: `make run_X069`

## Scenario

RUN_PREP issued while OPQ is mid-drain

## Stimulus

drive two OPQ packets and drop the tail during run-control restart

## Pass Criteria

one packet drains, one packet is dropped, and the DMA event closes cleanly

## Evidence

- Transcript: `tb_int/sim/X069/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
