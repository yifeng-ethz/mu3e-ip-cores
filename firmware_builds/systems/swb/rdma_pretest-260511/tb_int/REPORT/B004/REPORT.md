# REPORT - B004

- bucket: `BASIC`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_b004.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_b004_test.sv`
- run: `make run_B004`

## Scenario

SWB RC RUNNING to TERMINATING with one in-flight packet

## Stimulus

drive one in-flight packet while moving RUNNING to TERMINATING

## Pass Criteria

the in-flight packet is accounted as dropped and no DMA event is emitted

## Evidence

- Transcript: `tb_int/sim/B004/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
