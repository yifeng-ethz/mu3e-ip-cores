# REPORT - B033

- bucket: `BASIC`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_b033.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_b033_test.sv`
- run: `make run_B033`

## Scenario

SWB SC read OPQ CSR UID via PCIe BAR

## Stimulus

host PCIe sc_tool issues one OPQ UID read

## Pass Criteria

transaction completes with expected OPQ identity and no bus error

## Evidence

- Transcript: `tb_int/sim/B033/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
