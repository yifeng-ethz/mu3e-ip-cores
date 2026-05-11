# REPORT - X001

- bucket: `ERROR`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_x001.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_x001_test.sv`
- run: `make run_X001`

## Scenario

mid-flight RESET while OPQ has SQEs in flight

## Stimulus

accept one SQE/OPQ packet then force the reset-drain model

## Pass Criteria

in-flight packet is accounted as dropped and no DMA event is emitted

## Evidence

- Transcript: `tb_int/sim/X001/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
