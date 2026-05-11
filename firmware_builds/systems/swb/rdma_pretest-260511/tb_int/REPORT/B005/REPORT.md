# REPORT - B005

- bucket: `BASIC`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_b005.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_b005_test.sv`
- run: `make run_B005`

## Scenario

SWB RC TERMINATING to IDLE after bounded drain

## Stimulus

drive one drainable packet then move TERMINATING to IDLE

## Pass Criteria

the packet drains and the final IDLE shadow is coherent

## Evidence

- Transcript: `tb_int/sim/B005/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
