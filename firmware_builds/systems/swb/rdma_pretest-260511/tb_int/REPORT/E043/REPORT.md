# REPORT - E043

- bucket: `EDGE`
- status: `PASS`
- alias: `E-SC-CONC-001` mapped to lint-legal `E043`
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_e043.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_e043_test.sv`
- run: `make run_E043`

## Scenario

concurrent PCIe sc_tool plus local JTAG arbitration

## Stimulus

overlap one PCIe slow-control access with one local JTAG fallback read

## Pass Criteria

only one master owns the selected transaction and no timeout is observed

## Evidence

- Transcript: `tb_int/sim/E043/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
