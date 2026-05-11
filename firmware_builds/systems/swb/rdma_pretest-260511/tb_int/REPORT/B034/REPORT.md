# REPORT - B034

- bucket: `BASIC`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_b034.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_b034_test.sv`
- run: `make run_B034`

## Scenario

SWB SC read rdma_subsystem CSR UID

## Stimulus

host PCIe sc_tool reads rdma_subsystem CSR UID

## Pass Criteria

read data is stable and timeout counter remains zero

## Evidence

- Transcript: `tb_int/sim/B034/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
